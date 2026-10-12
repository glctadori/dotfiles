local M = {}

local function wiki_for(buf)
  local file = vim.api.nvim_buf_get_name(buf)
  local best
  for _, wiki in ipairs(vim.g.vimwiki_list or {}) do
    local path = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(wiki.path), ":p")):gsub("/$", "")
    local ext = wiki.ext or ".wiki"
    if wiki.syntax == "markdown" and file:sub(1, #path + 1) == path .. "/"
      and file:sub(-#ext) == ext and (not best or #path > #best.path) then
      best = { path = path, ext = ext }
    end
  end
  return best
end

-- vim.fs.relpath only handles descendants; wiki links also need ../ siblings.
local function relative(from, to)
  local source, target = vim.split(from, "/", { trimempty = true }), vim.split(to, "/", { trimempty = true })
  local common = 0
  while source[common + 1] and source[common + 1] == target[common + 1] do
    common = common + 1
  end
  local parts = {}
  for _ = common + 1, #source do parts[#parts + 1] = ".." end
  for i = common + 1, #target do parts[#parts + 1] = target[i] end
  return table.concat(parts, "/")
end

function M.open(insert)
  local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  local wiki = wiki_for(buf)
  if not wiki then return end
  local cursor = vim.api.nvim_win_get_cursor(win)
  local row, col = cursor[1] - 1, cursor[2]
  local directory = vim.fs.dirname(vim.api.nvim_buf_get_name(buf))
  local link

  Snacks.picker.files({
    title = "Wiki: inserisci link",
    cwd = wiki.path,
    ft = wiki.ext:sub(2),
    hidden = true,
    ignored = true,
    confirm = function(picker, item)
      local path = Snacks.picker.util.path(item)
      if not path then return end
      local destination = relative(directory, path):sub(1, -#wiki.ext - 1)
      local label = vim.fs.basename(destination):gsub("([\\%[%]])", "\\%1")
      -- Backslash escapes preserve filenames for Vimwiki's resolver too.
      destination = destination:gsub("([\\()<>])", "\\%1")
      if destination:find("%s") then destination = "<" .. destination .. ">" end
      link = "[" .. label .. "](" .. destination .. ")"
      picker:close()
    end,
    on_close = function()
      -- close() schedules window destruction after on_close; restore after it.
      vim.schedule(function()
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then return end
          vim.api.nvim_set_current_win(win)
          vim.api.nvim_win_set_buf(win, buf)
          if link then
            vim.api.nvim_buf_set_text(buf, row, col, row, col, { link })
            col = col + #link
          end
          if insert then
            local length = #vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
            vim.api.nvim_win_set_cursor(win, { row + 1, col })
            vim.cmd(col >= length and "startinsert!" or "startinsert")
          else
            vim.api.nvim_win_set_cursor(win, cursor)
          end
        end)
      end)
    end,
  })
end

function M.setup()
  local function attach(buf)
    local ft = vim.bo[buf].filetype
    if (ft == "vimwiki" or ft == "markdown") and wiki_for(buf) then
      -- Keep global window/buffer mappings, including after configuration reload.
      for _, key in ipairs({ "<leader>wh", "<leader>whh", "<leader>wd" }) do
        pcall(vim.keymap.del, "n", key, { buffer = buf })
      end
      vim.keymap.set("n", "<leader>wi", function() M.open(false) end,
        { buffer = buf, desc = "Wiki: inserisci link" })
      -- <Cmd> keeps Insert mode and its exact byte column, including end of line.
      vim.keymap.set("i", "[[", "<Cmd>lua require('wiki_links').open(true)<CR>",
        { buffer = buf, desc = "Wiki: inserisci link" })
    end
  end
  vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
    group = vim.api.nvim_create_augroup("WikiLinks", { clear = true }),
    callback = function(event) attach(event.buf) end,
  })
  attach(vim.api.nvim_get_current_buf())
end

return M
