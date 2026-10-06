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
vim.opt.showmode = false
vim.opt.laststatus = 3
vim.opt.wrap = false
vim.opt.spelllang = { "en", "it" }
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.background = "dark"
vim.opt.clipboard = "unnamedplus"
vim.opt.shortmess:append("I")

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

vim.opt.autoread = true

vim.api.nvim_create_autocmd({
  "FocusGained",
  "BufEnter",
  "CursorHold",
}, {
  command = "checktime",
})

vim.opt.guicursor = {
  "n-v-c:block",
  "i-ci-ve:ver25",
  "r-cr:hor20",
  "o:hor50",
  "t:ver25",
}
