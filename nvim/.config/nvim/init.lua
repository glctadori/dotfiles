-- Small, independent editor for notes, code and files edited by external agents.
if vim.fn.has("nvim-0.11.6") == 0 then
  error("nvim-minimal requires Neovim 0.11.6 or newer (Ubuntu 26.04)")
end

require("config.options")
require("config.external_changes").setup()
require("config.lazy")
require("chat")
require("config.keymaps")
