-- Offline adapter regression checks: nvim --headless -u NONE -l ~/.config/nvim/tests/claude.lua
vim.opt.rtp:prepend(vim.fn.expand('~/.config/nvim'))
local notifications, sent, mentions = {}, {}, {}
local connected = true
local editor = vim.api.nvim_get_current_buf()
local term_buf = vim.api.nvim_create_buf(false, true)
local job
vim.api.nvim_buf_call(term_buf, function() job = vim.fn.termopen({'cat'}) end)
vim.notify = function(message) notifications[#notifications + 1] = message end
package.loaded['claudecode'] = {
  is_claude_connected = function() return connected end,
  send_at_mention = function(path) mentions[#mentions + 1] = path; return true end,
}
package.loaded['claudecode.terminal'] = {
  get_active_terminal_bufnr = function() return term_buf end,
  send_to_terminal = function(text, opts) sent[#sent + 1] = {text=text, focus=opts.focus}; return true end,
}
local claude = require('claude')
local input
vim.ui.input = function(_, cb) input = cb end
claude.message(); input(nil); assert(#sent == 0)
claude.message(); input('   '); assert(#sent == 0)
claude.message(); input('hello'); assert(sent[1].text == 'hello' and not sent[1].focus)
claude.message(); connected = false; input('stale'); assert(#sent == 1)
input = nil; claude.message(); assert(input == nil)
connected = true
vim.api.nvim_set_current_buf(editor)
vim.api.nvim_buf_set_lines(editor, 0, -1, false, {'aèz', 'second', 'third'})
-- Real characterwise selection, including UTF-8, and linewise multiline selection.
vim.cmd('normal! gg0vl')
claude.selection(); assert(sent[#sent].text == 'aè', vim.inspect(sent[#sent]))
vim.cmd('normal! ggVj')
claude.selection(); assert(sent[#sent].text == 'aèz\nsecond')
vim.cmd('normal! gg0llvh')
claude.selection(); assert(sent[#sent].text == 'èz')
vim.o.selection = 'exclusive'
vim.cmd('normal! gg0vll')
claude.selection(); assert(sent[#sent].text == 'aè')
vim.o.selection = 'inclusive'
vim.cmd('normal! gg0\22j')
local count = #sent
claude.selection(); assert(#sent == count and notifications[#notifications]:find('Visual block'))
vim.cmd('normal! \27')
claude.clear(); assert(sent[#sent].text == '/clear' and not sent[#sent].focus)
claude.model(); assert(sent[#sent].text == '/model' and sent[#sent].focus)
local original_send = vim.fn.chansend
vim.fn.chansend = function(chan, bytes) assert(chan == job and bytes == '\27'); return 1 end
claude.interrupt()
vim.fn.chansend = original_send
local picker_opts
Snacks = {picker = {
  files = function(opts) picker_opts = opts end,
  buffers = function(opts) picker_opts = opts end,
  util = {path = function(entry) return entry.cwd .. '/' .. entry.file end},
}}
local closed = false
local selected = {}
local picker = {selected=function() return selected end, close=function() closed=true end}
claude.files(); assert(#mentions == 0) -- Closing without confirm never sends.
selected = {{file='a file.lua'}, {file='b.lua'}, {file='a file.lua'}}
picker_opts.confirm(picker, nil)
vim.wait(100, function() return #mentions == 2 end)
assert(closed and #mentions == 2 and mentions[1]:match('/a file.lua$'))
local named = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(named, '/tmp/claude buffer.lua')
claude.buffers()
selected = {{buf=editor}, {buf=term_buf}, {buf=named}}
picker_opts.confirm(picker, nil)
vim.wait(100, function() return #mentions == 3 end)
assert(#mentions == 3 and mentions[3] == '/tmp/claude buffer.lua')
assert(notifications[#notifications]:find('Saltati'))
claude.files(); selected = {{file='late.lua'}}; connected = false
picker_opts.confirm(picker, nil); vim.wait(20); assert(#mentions == 3)
local project = require('project')
local directory = vim.fn.tempname()
vim.fn.mkdir(directory .. '/repo/.git', 'p')
vim.fn.mkdir(directory .. '/repo/sub', 'p')
vim.api.nvim_buf_set_name(named, directory .. '/repo/sub/file.lua')
assert(project.root(named) == directory .. '/repo')
vim.api.nvim_buf_set_name(named, directory .. '/outside.lua')
assert(project.root(named) == directory)
assert(project.root(editor) == vim.fn.getcwd())
assert(project.root(term_buf) == vim.fn.getcwd())
vim.fn.delete(directory, 'rf')
vim.fn.jobstop(job)
print('PASS: messages, cancellation, disconnected session, UTF-8/reversed/multiline/block selections, controls, multi-file picker, special buffers')
vim.cmd.qa({bang=true})
