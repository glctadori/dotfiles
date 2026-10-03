-- Keep essential editing behavior explicit instead of inheriting LazyVim defaults.
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.mouse = "a"
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.undofile = true
vim.opt.autoread = true
vim.opt.autowrite = false
vim.opt.autowriteall = false
vim.opt.wrap = false
vim.opt.spelllang = { "en", "it" }
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.clipboard = vim.env.SSH_CONNECTION and "" or "unnamedplus"
require("config.remote_clipboard").setup()
vim.opt.background = "dark"

vim.filetype.add({ extension = { ino = "cpp", mdx = "markdown.mdx" } })
local group = vim.api.nvim_create_augroup("minimal_editing", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "markdown", "markdown.mdx", "vimwiki", "text", "gitcommit" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.spell = true
    vim.opt_local.conceallevel = 2
  end,
})
vim.api.nvim_create_autocmd("TextYankPost", {
  group = group,
  callback = function()
    vim.hl.on_yank()
  end,
})

vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Close buffer" })
vim.keymap.set("n", "<leader>qq", "<cmd>quit<cr>", { desc = "Quit window" })
vim.keymap.set("n", "<leader>xd", vim.diagnostic.open_float, { desc = "Line diagnostics" })
vim.keymap.set("n", "<leader>xq", vim.diagnostic.setqflist, { desc = "Diagnostics in quickfix" })
