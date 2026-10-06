local M = {}

local function root()
  local file = vim.api.nvim_buf_get_name(0)
  local start = file ~= "" and vim.fs.dirname(file) or vim.fn.getcwd()

  return vim.fs.root(start, {
    ".git",
    "pyproject.toml",
    "platformio.ini",
    "CMakeLists.txt",
  }) or start
end

vim.keymap.set("n", "S", ":%s//g<Left><Left>", {
  desc = "Replace all",
})

vim.keymap.set("v", "S", ":s//g<Left><Left>", {
  desc = "Replace selection",
})

-- Window management
local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, {
    silent = true,
    desc = desc,
  })
end

-- Move between windows
map("n", "<leader>wh", "<C-w>h", "Window left")
map("n", "<leader>wj", "<C-w>j", "Window down")
map("n", "<leader>wk", "<C-w>k", "Window up")
map("n", "<leader>wl", "<C-w>l", "Window right")

-- Splits
map("n", "<leader>wv", "<C-w>v", "Split vertical")
map("n", "<leader>ws", "<C-w>s", "Split horizontal")

-- Close window
map("n", "<leader>wq", "<C-w>q", "Close window")

vim.keymap.set("n", "<leader>qq", "<cmd>quit<cr>", { desc = "Quit window" })
-- Delete buffer
map("n", "<leader>wd", "<cmd>bdelete<cr>", "Delete buffer")

-- Maximize / restore window
local maximized = false

map("n", "<leader>wm", function()
  if maximized then
    vim.cmd("wincmd =")
    maximized = false
  else
    vim.cmd("wincmd _")
    vim.cmd("wincmd |")
    maximized = true
  end
end, "Maximize window")

local resize_active = false

local function resize_mode()
  if resize_active then
    return
  end

  resize_active = true
  vim.notify("RESIZE: h j k l | q/Esc exit")

  local opts = { buffer = true, silent = true }

  vim.keymap.set("n", "l", "<cmd>vertical resize -2<cr>", opts)
  vim.keymap.set("n", "h", "<cmd>vertical resize +2<cr>", opts)
  vim.keymap.set("n", "k", "<cmd>resize +1<cr>", opts)
  vim.keymap.set("n", "j", "<cmd>resize -1<cr>", opts)

  local function exit_resize()
    for _, key in ipairs({ "h", "j", "k", "l", "q", "<Esc>" }) do
      pcall(vim.keymap.del, "n", key, { buffer = true })
    end

    resize_active = false
    vim.notify("RESIZE: off")
  end

  vim.keymap.set("n", "q", exit_resize, opts)
  vim.keymap.set("n", "<Esc>", exit_resize, opts)
end

vim.keymap.set("n", "<leader>wr", resize_mode, {
  desc = "Resize mode",
})

-- Explorer
vim.keymap.set("n", "<leader>ee", function()
  Snacks.explorer({ cwd = root() })
end, { desc = "Explorer" })

vim.keymap.set("n", "<leader>eE", function()
  Snacks.explorer({ cwd = vim.fn.expand("~") })
end, { desc = "Explorer global" })

-- Buffers
vim.keymap.set("n", "<leader>bb", function()
  Snacks.picker.buffers()
end, { desc = "Buffers" })

vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Close buffer" })

-- Files
vim.keymap.set("n", "<leader>fs", "<cmd>write<cr>", {
  desc = "Save file",
})

vim.keymap.set("n", "<leader>ff", function()
  Snacks.picker.files({ cwd = root() })
end, { desc = "Find files" })


vim.keymap.set("n", "<leader>fF", function()
  Snacks.picker.files({ cwd = vim.fn.expand("~") })
end, { desc = "Find files global" })

vim.keymap.set("n", "<leader>fr", function()
  Snacks.picker.recent()
end, {
  desc = "Recent files",
})

vim.keymap.set("n", "<leader>fg", function()
  Snacks.picker.grep({ cwd = root() })
end, { desc = "Grep" })

vim.keymap.set("n", "<leader>fG", function()
  Snacks.picker.grep({ cwd = vim.fn.expand("~") })
end, { desc = "Grep global" })

local sudo = require("sudo")

vim.keymap.set("n", "<leader>fS", sudo.write, {
  desc = "File: sudo write",
})


-- Diagnostics
vim.keymap.set("n", "<leader>xd", vim.diagnostic.open_float, { desc = "Line diagnostics" })
vim.keymap.set("n", "<leader>xq", vim.diagnostic.setqflist, { desc = "Diagnostics in quickfix" })

-- Lsp

function M.lsp(buf)
  local opts = function(desc)
    return { buffer = buf, desc = desc }
  end

  vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts("Definition"))
  vim.keymap.set("n", "gr", vim.lsp.buf.references, opts("References"))
  vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, opts("Rename symbol"))
  vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts("Code action"))
end

-- Git
vim.keymap.set("n", "<leader>gg", "<cmd>Neogit<cr>", { desc = "Git" })

-- Format
vim.keymap.set({ "n", "v" }, "<leader>cf", function()
  require("conform").format()
end, { desc = "Format" })

-- Gitsigns
function M.gitsigns(buf)
  local gs = require("gitsigns")

  local function map(key, action, desc)
    vim.keymap.set("n", key, action, {
      buffer = buf,
      desc = desc,
    })
  end

  map("<leader>gn", function()
    gs.nav_hunk("next")
  end, "Next hunk")

  map("<leader>gp", function()
    gs.nav_hunk("prev")
  end, "Previous hunk")

  map("<leader>gv", gs.preview_hunk, "Preview hunk")
  map("<leader>gs", gs.stage_hunk, "Stage hunk")
  map("<leader>gr", gs.reset_hunk, "Reset hunk")
end

local terminal = require("terminal")

-- Terminal
vim.keymap.set({ "n", }, "<leader>t", terminal.toggle, {
  desc = "Toggle terminal",
})

vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], {
  desc = "Terminal window commands",
})

vim.keymap.set("t", "<C-]>", [[<C-\><C-n><Space>]], {
  desc = "Terminal → Neovim leader",
})

-- Terminal: Esc entra nel Normal mode di Neovim
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], {
  desc = "Terminal normal mode",
})

-- Inbox
vim.keymap.set("n", "<leader>ii", function()
  vim.ui.input({ prompt = "Inbox > " }, function(input)
    if input and input ~= "" then
      vim.fn.system({ "add-to-inbox", input })
    end
  end)
end, { desc = "Inbox: add" })

vim.keymap.set("n", "<leader>io", "<cmd>edit ~/in/inbox.md<cr>",
  { desc = "Inbox: open" })


return M
