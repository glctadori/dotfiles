require("options")
require("bootstrap")
require("terminal")
require("chat")
require("keymaps")
require("sudo")

-- RPC socket for external commands
local socket_dir = vim.fn.expand("~/.cache/nvim/sockets")
vim.fn.mkdir(socket_dir, "p")

local socket = socket_dir .. "/" .. vim.fn.getpid() .. ".sock"
vim.fn.serverstart(socket)

-- Carica il tema corrente definito in ~/.config/themes/current/nvim.lua
dofile(vim.fn.expand("~/.config/themes/current/nvim.lua"))
