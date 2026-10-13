-- A small read-only viewer: normal Vim navigation, system clipboard, q to close.
vim.opt.clipboard = "unnamedplus"
vim.opt.mouse = "a"
vim.opt.termguicolors = true
vim.opt.number = false
vim.opt.relativenumber = false
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.swapfile = false
vim.opt.undofile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.modeline = false
vim.opt.shadafile = "NONE"
vim.opt.laststatus = 2
vim.opt.statusline = " COPY · hjkl / cerca · v seleziona · y copia · q chiude %=%l/%L "
vim.cmd("syntax enable")

-- Reuse the current theme without starting the editor's other plugins.
local theme = vim.fn.expand("~/.config/themes/current/nvim.lua")
if vim.fn.filereadable(theme) == 1 then
  local plugins = vim.fn.stdpath("data") .. "/lazy/"
  for _, name in ipairs({ "everforest-nvim", "gruvbox.nvim", "tokyonight.nvim", "kanagawa.nvim", "catppuccin" }) do
    local path = plugins .. name
    if vim.fn.isdirectory(path) == 1 then
      vim.opt.runtimepath:append(path)
    end
  end
  local ok, everforest = pcall(require, "everforest")
  if ok then
    everforest.setup({ background = "medium" })
  end
  local loaded, err = pcall(dofile, theme)
  if not loaded then
    vim.notify("Tema copy mode: " .. tostring(err), vim.log.levels.WARN)
  end
end

vim.keymap.set({ "n", "x" }, "q", "<Cmd>qa!<CR>", { silent = true })
vim.keymap.set({ "n", "x" }, "j", "gj", { silent = true })
vim.keymap.set({ "n", "x" }, "k", "gk", { silent = true })

local function prepare()
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  vim.bo.filetype = "markdown"
  vim.bo.modified = false
  vim.bo.readonly = true
  vim.bo.modifiable = false
  vim.wo.conceallevel = 0 -- Keep source LaTeX and Markdown available for yanking.
  vim.cmd("normal! G")
end

vim.api.nvim_create_autocmd("StdinReadPost", {
  callback = function()
    -- The stock scrollback_pager also passes ANSI formatting to Neovim.
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    for i, line in ipairs(lines) do
      lines[i] = line:gsub("\27%].-\27\\", ""):gsub("\27%].-\7", "")
        :gsub("\27_.-\27\\", ""):gsub("\27_.-\7", "")
        :gsub("\27%[[0-?]*[ -/]*[@-~]", ""):gsub("\r", "")
    end
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    prepare()
  end,
})
vim.api.nvim_create_autocmd("VimEnter", { callback = prepare })

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    local filename = vim.env.KITTY_COPY_FILE
    local cache = (vim.env.XDG_CACHE_HOME or vim.fn.expand("~/.cache")) .. "/kitty-copy-mode/"
    if filename and filename:sub(1, #cache) == cache
      and filename:sub(#cache + 1):match("^view%-[^/]+%.md$") then
      vim.fn.delete(filename)
    end
  end,
})
