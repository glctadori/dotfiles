local M = {}

local buf = nil
local win = nil
local job = nil

local function append(text)
  if not buf or not vim.api.nvim_buf_is_valid(buf) or text == "" then
    return
  end

  vim.bo[buf].modifiable = true

  local n = vim.api.nvim_buf_line_count(buf)
  local last = vim.api.nvim_buf_get_lines(buf, n - 1, n, false)[1] or ""

  local parts = vim.split(text, "\n", { plain = true })

  -- Primo pezzo continua la riga esistente
  vim.api.nvim_buf_set_lines(
    buf,
    n - 1,
    n,
    false,
    { last .. parts[1] }
  )

  -- Solo i newline reali creano nuove righe
  if #parts > 1 then
    vim.api.nvim_buf_set_lines(
      buf,
      -1,
      -1,
      false,
      vim.list_slice(parts, 2)
    )
  end

  vim.bo[buf].modifiable = false

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_cursor(
      win,
      { vim.api.nvim_buf_line_count(buf), 0 }
    )
  end
end

local function start_chat()
  if job then
    return
  end

  job = vim.fn.jobstart({ "chat", "--pipe" }, {
    stdin = "pipe",
    stdout_buffered = false,

    on_stdout = function(_, data)
      if data then
        vim.schedule(function()
          append(table.concat(data, "\n"))
        end)
      end
    end,

    on_stderr = function(_, data)
      if data then
        vim.schedule(function()
          append(table.concat(data, "\n"))
        end)
      end
    end,

    on_exit = function()
      job = nil
    end,
  })
end

function M.send()
  if not job then
    return
  end

  vim.ui.input({ prompt = "You: " }, function(input)
    if not input or input == "" then
      return
    end

    append("\n## Me\n\n" .. input .. "\n\n## Assistant\n")

    vim.fn.chansend(job, vim.json.encode({
      type = "message",
      text = input,
    }) .. "\n")
  end)
end

function M.toggle()
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
    win = nil
    return
  end

  -- Ricorda dove stavo lavorando
  local previous_win = vim.api.nvim_get_current_win()

  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    buf = vim.api.nvim_create_buf(false, true)

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "markdown"

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "# Chat",
      "",
    })

    vim.bo[buf].modifiable = false
  end

  vim.cmd("botright vsplit")
  win = vim.api.nvim_get_current_win()

  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_width(win, 60)

  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].breakindent = true

  start_chat()

  -- Torna al buffer/finestra precedente
  if vim.api.nvim_win_is_valid(previous_win) then
    vim.api.nvim_set_current_win(previous_win)
  end
end

function M.file()
  if not job then
    return
  end

  Snacks.picker.files({
    confirm = function(picker, item)
      picker:close()

      if not item then
        return
      end

      local path = vim.fn.fnamemodify(item.file, ":p")

      vim.ui.input({ prompt = "You: " }, function(input)
        if not input or input == "" then
          return
        end

        append("\n## Me\n\n" .. input .. "\n\n## Assistant\n")

        vim.fn.chansend(job, vim.json.encode({
          type = "file",
          path = path,
          prompt = input,
        }) .. "\n")
      end)
    end,
  })
end

function M.clear()
  if not job then
    return
  end

  vim.fn.chansend(job, vim.json.encode({
    type = "clear",
  }) .. "\n")

  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "# Chat",
      "",
    })
    vim.bo[buf].modifiable = false
  end
end

function M.buffer()
  if not job then
    return
  end

  vim.ui.picker.buffers({
    confirm = function(picker, item)
      picker:close()

      if not item then
        return
      end

      local target_buf = item.buf

      if not target_buf or not vim.api.nvim_buf_is_valid(target_buf) then
        return
      end

      local name = vim.api.nvim_buf_get_name(target_buf)
      if name == "" then
        name = "[No Name]"
      else
        name = vim.fn.fnamemodify(name, ":~:.")
      end

      local lines = vim.api.nvim_buf_get_lines(
        target_buf,
        0,
        -1,
        false
      )

      local content = table.concat(lines, "\n")

      vim.ui.input({ prompt = "You: " }, function(input)
        if not input or input == "" then
          return
        end

        append(
          "\n## Me\n\n"
          .. input
          .. "\n\n"
          .. "_Buffer: "
          .. name
          .. "_\n\n"
          .. "## Assistant\n"
        )

        vim.fn.chansend(job, vim.json.encode({
          type = "context",
          name = name,
          text = content,
          prompt = input,
        }) .. "\n")
      end)
    end,
  })
end

function M.visual()
  if not job then
    return
  end

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local lines = vim.api.nvim_buf_get_text(
    0,
    start_pos[2] - 1,
    start_pos[3] - 1,
    end_pos[2] - 1,
    end_pos[3],
    {}
  )

  local content = table.concat(lines, "\n")

  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    name = "[No Name]"
  else
    name = vim.fn.fnamemodify(name, ":~:.")
  end

  vim.ui.input({ prompt = "You: " }, function(input)
    if not input or input == "" then
      return
    end

    append(
      "\n## Me\n\n"
      .. input
      .. "\n\n"
      .. "_Selection: "
      .. name
      .. "_\n\n"
      .. "## Assistant\n"
    )

    vim.fn.chansend(job, vim.json.encode({
      type = "context",
      name = name .. " (selection)",
      text = content,
      prompt = input,
    }) .. "\n")
  end)
end

local function show_diff(original, replacement, on_apply)
  local oldfile = vim.fn.tempname()
  local newfile = vim.fn.tempname()

  vim.fn.writefile(vim.split(original, "\n", { plain = true }), oldfile)
  vim.fn.writefile(vim.split(replacement, "\n", { plain = true }), newfile)

  local diff = vim.fn.system({
    "diff",
    "-u",
    "--label", "original",
    "--label", "AI edit",
    oldfile,
    newfile,
  })

  vim.fn.delete(oldfile)
  vim.fn.delete(newfile)

  -- Nessuna modifica
  if vim.v.shell_error == 0 then
    vim.notify("AI: no changes")
    return
  end

  local diff_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(diff_buf, "AI Diff")

  vim.bo[diff_buf].buftype = "nofile"
  vim.bo[diff_buf].bufhidden = "wipe"
  vim.bo[diff_buf].swapfile = false
  vim.bo[diff_buf].filetype = "diff"

  vim.api.nvim_buf_set_lines(
    diff_buf,
    0,
    -1,
    false,
    vim.split(diff, "\n", { plain = true })
  )

  vim.cmd("botright new")

  local diff_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(diff_win, diff_buf)

  local function close()
    if vim.api.nvim_win_is_valid(diff_win) then
      vim.api.nvim_win_close(diff_win, true)
    end
  end

  vim.keymap.set("n", "y", function()
    close()
    on_apply()
  end, {
    buffer = diff_buf,
    nowait = true,
    desc = "Apply AI edit",
  })

  vim.keymap.set("n", "q", function()
    close()
  end, {
    buffer = diff_buf,
    nowait = true,
    desc = "Reject AI edit",
  })
end

function M.edit()
  vim.cmd("normal! \27")

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local target_buf = vim.api.nvim_get_current_buf()

  local start_row = start_pos[2] - 1
  local start_col = start_pos[3] - 1
  local end_row = end_pos[2] - 1

  -- Riga finale originale: serve per calcolare correttamente end_col
  local end_line = vim.api.nvim_buf_get_lines(
    target_buf,
    end_row,
    end_row + 1,
    false
  )[1] or ""

  local end_col = math.min(end_pos[3], #end_line)

  local lines = vim.api.nvim_buf_get_text(
    target_buf,
    start_row,
    start_col,
    end_row,
    end_col,
    {}
  )

  local original = table.concat(lines, "\n")

  vim.ui.input({ prompt = "Edit: " }, function(input)
    if not input or input == "" then
      return
    end

    local prompt =
        "Modifica il seguente testo secondo la richiesta.\n"
        .. "Rispondi soltanto con il testo sostitutivo finale, "
        .. "senza markdown, code fence o spiegazioni esterne.\n"
        .. "Puoi aggiungere commenti direttamente nel codice quando "
        .. "sono utili a chiarire le modifiche.\n\n"
        .. "TESTO:\n"
        .. original
        .. "\n\nRICHIESTA:\n"
        .. input

    vim.g.ai_status = "editing..."
    vim.cmd("redrawstatus")

    vim.system(
      { "llm" },
      {
        stdin = prompt,
        text = true,
      },
      function(result)
        vim.schedule(function()
          vim.g.ai_status = nil
          vim.cmd("redrawstatus")
          if result.code ~= 0 then
            vim.notify(
              result.stderr or "LLM error",
              vim.log.levels.ERROR
            )
            return
          end

          local replacement = result.stdout:gsub("%s+$", "")

          -- Rimuove eventuali code fence prodotti dal modello
          replacement = replacement:gsub("^```[%w_+-]*%s*\n", "")
          replacement = replacement:gsub("\n```%s*$", "")

          show_diff(original, replacement, function()
            vim.api.nvim_buf_set_text(
              target_buf,
              start_row,
              start_col,
              end_row,
              end_col,
              vim.split(replacement, "\n", { plain = true })
            )

            vim.notify("AI edit applied")
          end)
        end)
      end
    )
  end)
end

vim.keymap.set("n", "<leader>ac", function()
  M.toggle()
end, { desc = "AI chat" })

vim.keymap.set("n", "<leader>as", function()
  M.send()
end, { desc = "AI send" })

vim.keymap.set("n", "<leader>af", function()
  M.file()
end, { desc = "AI file" })

vim.keymap.set("n", "<leader>ax", function()
  M.clear()
end, { desc = "AI clear chat" })

vim.keymap.set("n", "<leader>ab", function()
  M.buffer()
end, { desc = "AI buffer" })

vim.keymap.set("v", "<leader>as", function()
  vim.cmd("normal! \27")
  M.visual()
end, { desc = "AI send selection" })

vim.keymap.set("v", "<leader>ae", function()
  M.edit()
end, { desc = "AI edit selection" })

return M
