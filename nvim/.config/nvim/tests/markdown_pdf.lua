-- Run: nvim --headless -u NONE -l nvim/.config/nvim/tests/markdown_pdf.lua
package.path = "nvim/.config/nvim/lua/?.lua;" .. package.path
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local file = root .. "/a note.md"
local pdf = root .. "/a note.pdf"
vim.fn.writefile({ "PDF fixture" }, pdf)
local messages, calls, opened = {}, {}, {}
vim.notify = function(message) messages[#messages + 1] = message end
local missing
vim.fn.executable = function(command) return command == missing and 0 or 1 end
vim.system = function(command, _, callback)
  calls[#calls + 1] = { command = command, callback = callback }
end
vim.fn.jobstart = function(command)
  opened[#opened + 1] = command
  return 1
end
local function finish(result)
  calls[#calls].callback(result)
  vim.wait(30)
end
local m = require("markdown_pdf")
m.setup()
m.run(false)
assert(#calls == 0, "Unnamed buffers must not convert")
vim.cmd.edit(vim.fn.fnameescape(file))
vim.bo.filetype = "markdown"
local function mappings()
  local commands = vim.api.nvim_buf_get_commands(0, {})
  assert(commands.MarkdownPreview and commands.MarkdownPrint)
  local maps = vim.api.nvim_buf_get_keymap(0, "n")
  local found = {}
  for _, mapping in ipairs(maps) do found[mapping.rhs] = true end
  assert(found["<Cmd>MarkdownPreview<CR>"] and found["<Cmd>MarkdownPrint<CR>"])
end
mappings()
vim.bo.filetype = "vimwiki"
mappings()
m.setup() -- Reload is safe.
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# Changed note", "", "- one" })
m.run(false)
assert(vim.deep_equal(vim.fn.readfile(file), { "# Changed note", "", "- one" }))
assert(vim.deep_equal(calls[1].command, { "markdown-pdf", file }))
m.run(true)
assert(#calls == 1, "Concurrent conversion must be blocked")
finish({ code = 0, stdout = pdf .. "\n" })
assert(vim.deep_equal(opened[1], { "zathura", pdf }))

m.run(true)
finish({ code = 0, stdout = pdf .. "\n" })
assert(vim.deep_equal(calls[#calls].command, { "print-duplex", pdf }))
local count = #calls
m.run(true)
assert(#calls == count, "Concurrent print must be blocked")
finish({ code = 0 })

m.run(true)
finish({ code = 1, stderr = "conversion failed" })
assert(messages[#messages] == "conversion failed")
assert(#calls == count + 1, "Failed conversion must not print")
assert(#opened == 1, "Failed conversion must not open an old PDF")
m.run(false)
finish({ code = 0, stdout = root .. "/missing.pdf\n" })
assert(#opened == 1)

missing = "markdown-pdf"
count = #calls
m.run(false)
assert(#calls == count)
missing = "print-duplex"
m.run(true)
assert(#calls == count)
missing = nil
vim.bo.readonly = true
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Cannot save" })
m.run(true)
assert(#calls == count, "Failed save must not convert or print")
vim.bo.readonly = false

-- A spawn error must release the lock, allowing a retry.
local system = vim.system
vim.system = function() error("spawn failed") end
m.run(false)
assert(messages[#messages]:match("spawn failed"))
vim.system = system
m.run(false)
assert(#calls == count + 1)
finish({ code = 1, stderr = "finished" })
vim.fn.delete(root, "rf")
print("markdown_pdf: all checks passed")
