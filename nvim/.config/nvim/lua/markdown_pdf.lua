local M = {}
local running = {}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Markdown PDF" })
end

function M.run(print_pdf)
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" or vim.bo[buf].buftype ~= "" then
    return notify("Salva prima la nota in un file Markdown", vim.log.levels.ERROR)
  end
  if running[file] then
    return notify("Conversione o stampa già in corso per questa nota", vim.log.levels.WARN)
  end
  local target = print_pdf and "print-duplex" or "zathura"
  for _, executable in ipairs({ "markdown-pdf", target }) do
    if vim.fn.executable(executable) ~= 1 then
      return notify("Comando mancante: " .. executable, vim.log.levels.ERROR)
    end
  end
  local saved, save_error = pcall(vim.cmd, "update")
  if not saved then return notify(tostring(save_error), vim.log.levels.ERROR) end

  running[file] = true
  notify("Generazione PDF…")
  local started, start_error = pcall(vim.system, { "markdown-pdf", file }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        running[file] = nil
        return notify(vim.trim(result.stderr or "") ~= "" and vim.trim(result.stderr)
          or "Conversione PDF fallita", vim.log.levels.ERROR)
      end
      local pdf = (result.stdout or ""):gsub("\r?\n$", "")
      if pdf == "" or vim.fn.filereadable(pdf) ~= 1 then
        running[file] = nil
        return notify("Il convertitore non ha restituito un PDF leggibile", vim.log.levels.ERROR)
      end
      if not print_pdf then
        running[file] = nil
        local job = vim.fn.jobstart({ target, pdf }, { detach = true })
        if job <= 0 then notify("Impossibile avviare Zathura", vim.log.levels.ERROR) end
        return
      end
      local launched, launch_error = pcall(vim.system, { target, pdf }, { text = true }, function(print_result)
        vim.schedule(function()
          running[file] = nil
          if print_result.code ~= 0 then
            notify(vim.trim(print_result.stderr or "") ~= "" and vim.trim(print_result.stderr)
              or "Stampa fallita", vim.log.levels.ERROR)
          end
        end)
      end)
      if not launched then
        running[file] = nil
        notify(tostring(launch_error), vim.log.levels.ERROR)
      end
    end)
  end)
  if not started then
    running[file] = nil
    notify(tostring(start_error), vim.log.levels.ERROR)
  end
end

function M.setup()
  local function attach(buf)
    if vim.bo[buf].filetype ~= "markdown" and vim.bo[buf].filetype ~= "vimwiki" then return end
    vim.api.nvim_buf_create_user_command(buf, "MarkdownPreview", function() M.run(false) end,
      { desc = "PDF: anteprima", force = true })
    vim.api.nvim_buf_create_user_command(buf, "MarkdownPrint", function() M.run(true) end,
      { desc = "PDF: stampa", force = true })
    vim.keymap.set("n", "<leader>fp", "<Cmd>MarkdownPreview<CR>",
      { buffer = buf, silent = true, desc = "PDF: anteprima" })
    vim.keymap.set("n", "<leader>fP", "<Cmd>MarkdownPrint<CR>",
      { buffer = buf, silent = true, desc = "PDF: stampa" })
  end
  vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
    group = vim.api.nvim_create_augroup("MarkdownPDF", { clear = true }),
    callback = function(event) attach(event.buf) end,
  })
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do attach(buf) end
end

return M
