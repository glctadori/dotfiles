-- Keep plugins and their state inside the trial's NVIM_APPNAME directories.
local path = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(path) then
  local output = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    path,
  })
  if vim.v.shell_error ~= 0 then
    error("Cannot install lazy.nvim:\n" .. output)
  end
end
vim.opt.rtp:prepend(path)
require("lazy").setup("plugins", {
  defaults = { lazy = false, version = false },
  checker = { enabled = false },
  change_detection = { notify = false },
  install = { colorscheme = { "everforest" } },
})
