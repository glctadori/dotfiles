-- Run: nvim --headless -u NONE -l nvim/.config/nvim/tests/knowledge_search.lua
local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
local original_stdpath = vim.fn.stdpath
vim.fn.stdpath = function(kind) return kind == 'state' and root or original_stdpath(kind) end
package.path = 'nvim/.config/nvim/lua/?.lua;' .. package.path
local messages, calls, picker, opened, jumped = {}, 0
vim.notify = function(message) messages[#messages + 1] = message end
vim.fn.executable = function() return 1 end
vim.fn.jobstart = function(command) opened = command; return 1 end
local pdf = root .. '/a book.pdf'
vim.fn.writefile({'fixture'}, pdf)
local hits = {{path = pdf, page = 490, score = 0.558, text = 'Ohm law'}}
local response
vim.system = function(command, _, callback)
  calls = calls + 1
  assert(command[1] == 'semantic-search')
  callback(response or {code = 0, stdout = vim.json.encode(hits)})
end
_G.Snacks = {picker = setmetatable({actions = {jump = function(_, item) jumped = item.pos end}}, {
  __call = function(_, options) picker = options end,
})}
local function run(module, corpus, query)
  module.run(corpus, query)
  vim.wait(20)
end
local m = require('knowledge_search')
run(m, 'library', 'Ohm')
assert(picker.items[1].page == 490)
picker.confirm({close = function() end}, picker.items[1])
assert(vim.deep_equal(opened, {'xdg-open', pdf}))
opened = nil
picker.confirm({close = function() end}, {file = root .. '/missing.pdf'})
assert(opened == nil)
local before = calls
package.loaded.knowledge_search = nil
m = require('knowledge_search')
m.show()
assert(picker.title == 'library: Ohm')
m.history()
assert(#picker.items == 1)
picker.confirm({close = function() end}, picker.items[1])
assert(calls == before, 'Reopening must not invoke semantic-search')
hits = {{path = pdf, line = 12, score = 0.5, text = 'wiki'}}
run(m, 'wiki', 'wiki query')
picker.confirm({close = function() end}, picker.items[1])
assert(vim.deep_equal(jumped, {12, 0}))
for i = 1, 51 do run(m, 'wiki', 'query ' .. i) end
m.history()
assert(#picker.items == 50)
local path = root .. '/knowledge-search/history.json'
local history = vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))
assert(history[1].query == 'query 51')
response = {code = 0, stdout = 'invalid'}
run(m, 'wiki', 'invalid')
assert(vim.json.decode(table.concat(vim.fn.readfile(path), '\n'))[1].query == 'query 51')
response = {code = 1, stderr = 'network failure'}
run(m, 'wiki', 'failed')
assert(messages[#messages] == 'network failure')
response = nil
hits = {}
run(m, 'wiki', 'empty')
m.history()
assert(picker.items[1].results.query == 'empty')
local selected_query
m.run = function(corpus, query) selected_query = {corpus, query} end
vim.ui.input = function(_, callback) callback(' manual query ') end
m.search('library')
assert(vim.deep_equal(selected_query, {'library', 'manual query'}))
selected_query = nil
vim.ui.input = function(_, callback) callback(nil) end
m.search('wiki')
assert(selected_query == nil)
vim.api.nvim_buf_set_lines(0, 0, -1, false, {'first line', 'second line'})
vim.api.nvim_win_set_cursor(0, {1, 0})
vim.api.nvim_feedkeys('Vj', 'nx', false)
m.search('wiki')
vim.wait(20)
assert(vim.deep_equal(selected_query, {'wiki', 'first line\nsecond line'}))
vim.api.nvim_win_set_cursor(0, {1, 0})
vim.api.nvim_feedkeys('v4l', 'nx', false)
m.search('library')
vim.wait(20)
assert(vim.deep_equal(selected_query, {'library', 'first'}))
vim.fn.writefile({'invalid json'}, path)
m.history()
assert(messages[#messages]:match('Nessuna ricerca salvata'))
vim.fn.delete(root, 'rf')
print('knowledge_search: all checks passed')
