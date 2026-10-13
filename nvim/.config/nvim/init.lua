require("options")
require("bootstrap")
require("terminal")
require("sudo")
require("keymaps")
require("markdown_pdf").setup()

-- RPC socket for external commands
local socket_dir = vim.fn.expand("~/.cache/nvim/sockets")
vim.fn.mkdir(socket_dir, "p")

local socket = socket_dir .. "/" .. vim.fn.getpid() .. ".sock"
vim.fn.serverstart(socket)

-- Carica il tema corrente definito in ~/.config/themes/current/nvim.lua
dofile(vim.fn.expand("~/.config/themes/current/nvim.lua"))
