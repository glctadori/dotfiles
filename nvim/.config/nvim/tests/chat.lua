local root = assert(os.getenv('CHAT_ROOT'))
package.path = root .. '/nvim/.config/nvim/lua/?.lua;' .. package.path
local M = require('chat')
local P = require('palette')
if os.getenv('CHAT_REAL_PICKER') then
  vim.opt.rtp:prepend(assert(os.getenv('SNACKS_ROOT')))
  Snacks=require('snacks')
  Snacks.setup({picker={enabled=true}})
  local dir=vim.fn.tempname(); vim.fn.mkdir(dir,'p')
  vim.fn.writefile({'---','profile: frontier','---','# Test','instruction'},dir..'/prompt-test.md')
  vim.fn.writefile({'source'},dir..'/source.md')
  vim.g.vimwiki_list={{path=dir,syntax='markdown'}}
  vim.cmd.edit(dir..'/source.md')
  P.open('chat')
  assert(vim.wait(1000,function() local p=Snacks.picker.get()[1]; return p and p:count()>=5 end))
  local picker=Snacks.picker.get()[1]
  for _,item in ipairs(picker:items()) do if item.text=='Current buffer' then picker.opts.confirm(picker,item); break end end
  assert(vim.wait(1000,function() local p=Snacks.picker.get()[1]; return p and p~=picker and p:count()==2 end))
  local prompts=Snacks.picker.get()[1]
  assert(prompts:items()[1].text=='New')
  assert(prompts.title:find('deepseek',1,true))
  local bound=false
  for _,map in ipairs(vim.api.nvim_buf_get_keymap(prompts.input.win.buf,'i')) do
    if map.lhs:lower()=='<c-e>' then bound=true end
  end
  assert(bound,'optional instruction shortcut missing')
  local selected
  vim.ui.select=function(_,_,cb) selected=cb end
  prompts:action('request_model'); selected('openai/gpt-6.1-sol')
  assert(prompts.title:find('openai/gpt-6.1-sol',1,true))
  prompts:action('request_thinking'); selected('high')
  assert(prompts.title:find(' · high',1,true))
  M.stop()
  assert(vim.wait(1000,function() return #Snacks.picker.get()==0 end))
  assert(not M._test.state())
  vim.fn.delete(dir,'rf')
  print('real Snacks picker smoke test passed')
  return
end
local t,pt=M._test,P._test
local function eq(a,b) assert(vim.deep_equal(a,b),vim.inspect(a)..' ~= '..vim.inspect(b)) end
local function encode(edits) return vim.json.encode({edits=edits}) end
local function full(text) return vim.json.encode({replacement=text}) end
local text='uno αβ\ndue\ntre'
eq(t.replacement(text,encode({{old_text='αβ',new_text='🎉'},{old_text='tre',new_text='quattro'}})),'uno 🎉\ndue\nquattro')
eq(t.replacement(text,'```json\n'..full('αβ')..'\n```'),'αβ')
eq(t.replacement('',full('new')),'new')
for _,bad in ipairs({'{}','{"edits":[]}','{"edits":','x\n'..full('x'),'{"replacement":"x","path":"other"}',full('x\0y'),encode({{old_text='',new_text='x'}}),encode({{old_text='missing',new_text='x'}}),encode({{old_text='uno',new_text='x'},{old_text='uno αβ',new_text='y'}})}) do eq(t.replacement(text,bad),nil) end
eq(t.replacement('aaa',encode({{old_text='aa',new_text='b'}})),nil)
local dir=vim.fn.tempname(); vim.fn.mkdir(dir..'/project/sub','p'); vim.fn.mkdir(dir..'/project/.git','p')
local path=dir..'/project/sub/target.md'; vim.fn.writefile({'disk'},path)
vim.cmd.edit(path); local target=vim.api.nvim_get_current_buf()
local function set(lines)
  vim.api.nvim_set_current_buf(target)
  vim.api.nvim_buf_set_lines(target,0,-1,false,lines)
end
set({'unsaved αβ','two'})
local s=t.snapshot({buf=target,path=path}); eq(s.text,'unsaved αβ\ntwo'); assert(t.unchanged(s))
set({'changed'}); assert(not t.unchanged(s)); set({'unsaved αβ','two'}); assert(not t.unchanged(s))
eq(M.source({path=path}).text,'unsaved αβ\ntwo')
eq(M.project_root(target),dir..'/project')
local cwd=vim.fn.getcwd(); vim.cmd.cd(vim.fn.expand('~')); eq(M.project_root(target),dir..'/project'); vim.cmd.cd(cwd)

-- Fake CLI transport and asynchronous UI: tests never run llm or access an API.
local stdout,exit,stderr,requests={},nil,nil,{}
local notifications={}
local executable=vim.fn.executable
vim.fn.executable=function(name) return name=='notify-send' and 1 or executable(name) end
vim.fn.jobstart=function(args,opts)
  if args[1]=='notify-send' then notifications[#notifications+1]=args; return 43 end
  stdout=opts.on_stdout; exit=opts.on_exit; stderr=opts.on_stderr; return 42
end
eq(M.statusline(),'')
vim.fn.chansend=function(_,data) requests[#requests+1]=vim.json.decode(data); return #data end
local input,selection_ui,pickeropts,picker,source_kind
vim.ui.input=function(_,cb) input=cb end
vim.ui.select=function(items,_,cb) selection_ui={items=items,cb=cb} end
local function capture(opts,kind)
  pickeropts=opts; source_kind=kind
  picker={closed=false,selected_items={},item=opts.items and opts.items[1],opts=opts}
  function picker:selected() return self.selected_items end
  function picker:current() return self.item end
  function picker:update_titles() end
  function picker:close()
    if self.closed then return end
    self.closed=true
    if self.opts.on_close then self.opts.on_close(self) end
  end
  if opts.on_show then opts.on_show(picker) end
  return picker
end
Snacks={picker=setmetatable({
  buffers=function(opts) return capture(opts,'buffers') end,
  files=function(opts) return capture(opts,'files') end,
  util={path=function(e)
    if e.file:sub(1,1)=='/' then return e.file end
    return e.cwd..'/'..e.file
  end},
},{__call=function(_,opts) return capture(opts,'items') end})}
local function flush() vim.wait(10,function() return false end) end
local function choose(name)
  local item
  for _,e in ipairs(pickeropts.items or {}) do if e.text==name then item=e end end
  assert(item,'missing item '..name)
  picker.item=item; pickeropts.confirm(picker,item); flush()
end
local function select_items(items)
  picker.selected_items=items; pickeropts.confirm(picker,items[1]); flush()
end
local function feed(str) stdout(42,vim.split(str,'\n',{plain=true})); flush() end
local function terminal(kind) feed('\n__CHAT_RESPONSE_'..(kind or 'DONE')..'__\n') end
local function key(k)
  for _,m in ipairs(vim.api.nvim_buf_get_keymap(vim.api.nvim_get_current_buf(),'n')) do if m.lhs==k then m.callback(); return end end
  error('missing key '..k)
end
local function last() return requests[#requests] end
local function visual(keys)
  vim.api.nvim_set_current_buf(target)
  vim.cmd('normal! '..keys)
end
local function edit(mode,visual_mode)
  vim.api.nvim_set_current_buf(target)
  P.open(mode,visual_mode)
  if mode=='contextual' and not visual_mode then choose('Current buffer') end
  choose('New'); input('change')
end

-- An edit started before opening chat must show its request and waiting state.
edit('isolated')
eq(M.status(),'AI: Thinking...')
local chatbuf
for _,w in ipairs(vim.api.nvim_list_wins()) do
  local b=vim.api.nvim_win_get_buf(w)
  if vim.bo[b].buftype=='nofile' and vim.bo[b].filetype=='markdown' then chatbuf=b end
end
assert(chatbuf,'edit must open the chat panel')
local function transcript() return table.concat(vim.api.nvim_buf_get_lines(chatbuf,0,-1,false),'\n') end
assert(transcript():find('Richiesta AI in corso',1,true))
assert(transcript():find('change',1,true))
assert(transcript():find('AI: Thinking...',1,true))
for _,w in ipairs(vim.fn.win_findbuf(chatbuf)) do
  eq(vim.api.nvim_eval_statusline(vim.wo[w].winbar,{winid=w,use_winbar=true}).str,'AI: Thinking...')
end
feed(full('visible edit proposal'))
eq(M.status(),'AI: Editing...')
terminal()
eq(M.status(),'AI: Review: y applica / q rifiuta')
assert(transcript():find('Modifica AI: completata',1,true))
assert(not transcript():find('"replacement"',1,true),'technical edit JSON must stay out of chat')
key('q')
eq(M.status(),'AI: Rifiutata')

-- Metadata defaults, independent thinking override and malformed values.
local parsed=assert(pt.parse('---\nprofile: rapido\nthinking: high\n---\n# Riordina\nbody'))
eq(parsed.title,'Riordina'); eq(parsed.text,'# Riordina\nbody')
eq(pt.effective(parsed,{}),{model='deepseek/deepseek-v4.1-flash',reasoning='high'})
eq(pt.effective({profile='frontier'},{}),{model='openai/gpt-6.1-sol',reasoning='high'})
eq(pt.effective({profile='rapido'},{}).reasoning,'none')
for _,bad in ipairs({'---\nprofile: missing\n---\nx','---\nthinking: max\n---\nx','---\nprofile: rapido\nprofile: frontier\n---\nx','---\nother: x\n---\nx','---\nprofile: rapido','---\nprofile: rapido\n---\n'}) do eq(pt.parse(bad),nil) end
local wiki=dir..'/wiki'; vim.fn.mkdir(wiki..'/nested','p'); vim.g.vimwiki_list={{path=wiki,syntax='markdown',ext='.md'}}
vim.fn.writefile({'# Index'},wiki..'/prompts.md')
vim.fn.writefile({'# Hidden'},wiki..'/nested/prompt-hidden.md')
vim.fn.writefile({'---','profile: frontier','---','# Ricerca','research'},wiki..'/prompt-ricerca.md')
vim.fn.writefile({'---','profile: rapido','---','# Riordina','reorder'},wiki..'/prompt-riordina.md')
eq(#pt.prompts(target),3); eq(pt.prompts(target)[1].text,'New')
vim.fn.writefile({'No heading'},wiki..'/prompt-added.md')
eq(#pt.prompts(target),4); eq(pt.prompts(target)[2].text,'added')

-- Visual -> Chat skips sources and uses the prompt override only once.
set({'abc αβ','second'})
visual('gg0v2l'); M.visual()
eq(last(),{type='message',text='abc'}); terminal()
visual('ggVj'); M.visual()
eq(last(),{type='message',text='abc αβ\nsecond'}); terminal()
visual('gg0v2l'); P.open('chat',true); choose('Solo selezione')
eq(last().type,'message'); eq(last().text,'abc')
eq(last().prompt,nil); eq(last().name,nil); terminal()
visual('gg0v2l'); P.open('chat',true); eq(pickeropts.items[1].text,'New')
choose('Ricerca'); eq(last().text,'SOURCE: '..path..' (selection)\nabc')
eq(last().type,'context'); eq(vim.trim(last().prompt),'# Ricerca\nresearch')
local displayed=false
for _,b in ipairs(vim.api.nvim_list_bufs()) do
  if vim.bo[b].buftype=='nofile' and vim.bo[b].filetype=='markdown' then
    local content=table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\n')
    displayed=content:find(last().text..'\n\nRichiesta:\n'..last().prompt,1,true) ~= nil
    if displayed then break end
  end
end
assert(displayed,'chat must display the selected text together with the prompt')
eq(last().model,'openai/gpt-6.1-sol'); eq(last().reasoning,'high'); terminal()
eq(M.settings(),{model='deepseek/deepseek-v4.1-flash',reasoning='none'})
M.send(); input('ordinary'); eq(last().model,nil)
eq(M.status(),'AI: Thinking...'); feed('answer'); eq(M.status(),'AI: Responding...')
eq(M.statusline(),'󰚩 Responding...')
local notification_count=#notifications
terminal(); eq(M.status(),'AI: Done')
eq(M.statusline(),''); eq(#notifications,notification_count+1)
eq(notifications[#notifications][4],'Risposta completata.')
terminal(); eq(#notifications,notification_count+1)

-- Visual -> Edit: exact selected text, diff, confirm, undo, disk unchanged.
visual('gg0v2l'); edit('isolated',true)
eq(last().history,'readonly'); eq(last().use_history,false); eq(last().text,'abc')
local before=#requests; feed(full('XYZ')); terminal(); eq(vim.bo.filetype,'diff')
vim.api.nvim_buf_call(target,function() vim.cmd('let &undolevels = &undolevels') end)
key('y'); eq(vim.api.nvim_buf_get_lines(target,0,-1,false),{'XYZ αβ','second'}); eq(#requests,before)
vim.api.nvim_buf_call(target,function() vim.cmd.undo() end)
eq(vim.api.nvim_buf_get_lines(target,0,-1,false),{'abc αβ','second'}); eq(vim.fn.readfile(path),{'disk'})
visual('gg0v2l'); edit('isolated',true); feed(full('cancelled')); terminal(); key('q')
eq(vim.api.nvim_buf_get_lines(target,0,-1,false),{'abc αβ','second'})

-- Contextual proposals record outcome, never technical JSON; closure is refusal.
edit('contextual'); eq(last().use_history,true); eq(last().history,'readonly')
feed(full('context result')); terminal(); key('q'); eq(last().type,'note')
assert(last().text:find('rifiutata',1,true)); assert(not last().text:find('"replacement"',1,true))
edit('contextual'); feed(full('applied')); terminal(); key('y')
assert(last().text:find('applicata al buffer, non salvata',1,true))
eq(vim.api.nvim_buf_get_lines(target,0,-1,false),{'applied'})
edit('contextual'); feed(full('closed')); terminal(); vim.cmd.close(); assert(last().text:find('rifiutata',1,true))
edit('contextual'); feed(full('stale')); terminal(); vim.api.nvim_buf_set_lines(target,0,-1,false,{'user edit'}); -- go back to diff
for _,w in ipairs(vim.api.nvim_list_wins()) do if vim.bo[vim.api.nvim_win_get_buf(w)].filetype=='diff' then vim.api.nvim_set_current_win(w) end end
key('y'); eq(vim.api.nvim_buf_get_lines(target,0,-1,false),{'user edit'}); assert(last().text:find('invalidata',1,true))
edit('contextual'); set({'during generation'}); feed(full('stale')); terminal(); eq(select(2,t.state()),nil)
eq(M.status(),'AI: Invalidata: buffer cambiato')
edit('isolated'); feed('Sure, here is the result'); terminal(); eq(select(2,t.state()),nil)

-- All marker split points and error recovery.
for _,marker in ipairs({'__CHAT_RESPONSE_DONE__','__CHAT_RESPONSE_ERROR__','__CHAT_RESPONSE_CANCELLED__'}) do
  for n=0,#marker do
    M.send(); input('test'); feed('result\n'..marker:sub(1,n)); assert(t.state())
    feed(marker:sub(n+1)..'\n'); eq(t.state(),nil)
  end
end
edit('isolated'); M.stop(); local count=#requests; P.open(); eq(#requests,count); terminal('CANCELLED'); eq(t.state(),nil)
P.open(); choose('Input'); local late=input; M.clear(); late('late'); eq(last().type,'clear'); eq(t.state(),nil)
edit('contextual'); feed(full('discard')); terminal(); count=#requests; M.clear(); eq(#requests,count+1); eq(last().type,'clear')
edit('contextual'); M.clear(); feed('late'); terminal('CANCELLED'); eq(last().type,'clear')

-- Full buffer, empty buffer, multiline linewise and UTF-8 byte endpoints.
set({''}); edit('isolated'); feed(full('new')); terminal(); key('y'); eq(vim.api.nvim_buf_get_lines(target,0,-1,false),{'new'})
set({'one','two','tail'}); visual('ggVj'); edit('isolated',true); eq(last().text,'one\ntwo')
feed(full('joined')); terminal(); key('y'); eq(vim.api.nvim_buf_get_lines(target,0,-1,false),{'joined','tail'})
set({'αβ x','second γδ','tail'}); visual('gg0vjl'); local selected=assert(M.selection()); eq(selected.text,'αβ x\nse')
-- Multiline replacement preserves both byte-exact boundaries and following lines.
visual('gg0v'); vim.cmd('normal! '..string.char(27))
vim.fn.setpos("'<",{0,1,3,0}); vim.fn.setpos("'>",{0,2,4,0})
edit('isolated',true); eq(last().text,'β x\nseco')
feed(full('NEW\nLINE')); terminal(); key('y')
eq(vim.api.nvim_buf_get_lines(target,0,-1,false),{'αNEW','LINEnd γδ','tail'})
set({'αβ x','second γδ','tail'})
visual('gg0lv'); selected=assert(M.selection()); eq(selected.text,'β')
visual('gg02lv2h'); selected=assert(M.selection()); eq(selected.text,'αβ ')
vim.o.selection='exclusive'
visual('gg0v2l'); selected=assert(M.selection()); eq(selected.text,'αβ')
visual('gg02lv2h'); selected=assert(M.selection()); eq(selected.text,'αβ')
vim.o.selection='inclusive'
visual('gg0'..string.char(22)..'j'); count=#requests; P.open('isolated',true); eq(#requests,count); vim.cmd('normal! '..string.char(27))

-- Project/global cwd, multi-file, unsaved loaded file content and file Edit.
vim.api.nvim_set_current_buf(target); P.open(); choose('Files root'); eq(pickeropts.cwd,dir..'/project')
select_items({{file='sub/target.md'}}); choose('New'); input('read'); assert(last().text:find('αβ x',1,true)); terminal()
local file=dir..'/project/other.md'; vim.fn.writefile({'other'},file)
P.open(); choose('Files global'); eq(pickeropts.cwd,vim.fn.expand('~'))
select_items({{file=path},{file=file}}); choose('New'); input('both')
assert(last().text:find('αβ x',1,true) and last().text:find('other',1,true)); terminal()
P.open('contextual'); choose('Files root'); select_items({{file='other.md'}}); choose('New'); input('change file')
feed(full('file proposal')); terminal(); local filebuf=vim.fn.bufnr(file); key('y')
eq(vim.api.nvim_buf_get_lines(filebuf,0,-1,false),{'file proposal'}); eq(vim.fn.readfile(file),{'other'})
P.open('contextual'); choose('Files root'); select_items({{file=file},{file=path}}); eq(t.state(),nil)
P.open(); choose('Buffers'); select_items({{buf=target},{buf=filebuf}}); choose('New'); input('buffers'); terminal()
P.open(); choose('Input'); input('free'); eq(last().type,'message'); eq(last().text,'free'); terminal()

-- Optional instruction and per-request picker settings do not alter defaults.
vim.api.nvim_set_current_buf(target); P.open(); choose('Current buffer')
local promptpicker=picker; local opts=pickeropts
for _,item in ipairs(opts.items) do if item.text=='Riordina' then promptpicker.item=item end end
opts.actions.request_model(promptpicker); selection_ui.cb('openai/gpt-6.1-sol')
opts.actions.request_thinking(promptpicker); selection_ui.cb('high')
opts.actions.with_instruction(promptpicker); flush(); input('keep headings')
eq(last().model,'openai/gpt-6.1-sol'); eq(last().reasoning,'high'); assert(last().prompt:find('keep headings',1,true)); terminal()
eq(M.settings().reasoning,'none')
M.model(); selection_ui.cb('openai/gpt-6.1-sol'); eq(last().type,'config')
M.thinking(); selection_ui.cb('medium'); eq(M.settings().reasoning,'medium')
eq(pt.effective({thinking='low'},{}),{model='openai/gpt-6.1-sol',reasoning='low'})
P.controls(); selection_ui.cb('Stop'); eq(t.state(),nil)

-- Every cancelled stage releases busy and ignores late callbacks.
P.open(); picker:close(); eq(t.state(),nil)
P.open(); choose('Buffers'); picker:close(); eq(t.state(),nil)
P.open(); choose('Current buffer'); picker:close(); eq(t.state(),nil)
P.open(); choose('Input'); input(nil); eq(t.state(),nil)
P.open(); choose('Current buffer'); local oldopts,oldpicker=pickeropts,picker; M.stop(); oldopts.confirm(oldpicker,oldopts.items[1]); flush(); eq(t.state(),nil)

-- Read-only/special/deleted/renamed guards and binary detection.
local guard=t.snapshot({buf=target,path=path}); assert(guard)
vim.bo[target].readonly=true; assert(not t.unchanged(guard)); P.open('isolated'); eq(t.state(),nil); vim.bo[target].readonly=false
vim.bo[target].modifiable=false; assert(not t.unchanged(guard)); vim.bo[target].modifiable=true
vim.api.nvim_buf_set_name(target,path..'.renamed'); assert(not t.unchanged(guard)); vim.api.nvim_buf_set_name(target,path)
local special=vim.api.nvim_create_buf(false,true); eq(t.snapshot({buf=special,path=''}),nil)
local binary=dir..'/binary.dat'; local handle=assert(io.open(binary,'wb')); handle:write('\255\254\0'); handle:close(); eq(M.source({path=binary}),nil)
P.open(); choose('Files root'); count=#requests; select_items({{file=binary},{file=file}}); eq(t.state(),nil); eq(#requests,count)
-- Root remains tied to the editor when invoked from the chat panel.
vim.api.nvim_set_current_buf(target); M.origin()
for _,w in ipairs(vim.api.nvim_list_wins()) do
  local b=vim.api.nvim_win_get_buf(w)
  if vim.bo[b].buftype=='nofile' and vim.bo[b].filetype=='markdown' then vim.api.nvim_set_current_win(w); break end
end
P.open(); choose('Files root'); eq(pickeropts.cwd,dir..'/project'); picker:close()
vim.api.nvim_set_current_buf(target)

-- Diff error/no-op and temporary cleanup; terminal exit and stale transport.
local system,tempname=vim.fn.system,vim.fn.tempname
local temps={}; vim.fn.tempname=function() local name=tempname(); temps[#temps+1]=name; return name end
edit('isolated'); vim.fn.system=function() error('diff failure') end; feed(full('new')); terminal(); eq(select(2,t.state()),nil)
for _,name in ipairs(temps) do eq(vim.fn.filereadable(name),0) end
vim.fn.system=system; vim.fn.tempname=tempname
edit('isolated'); feed(full(table.concat(vim.api.nvim_buf_get_lines(target,0,-1,false),'\n'))); terminal(); eq(select(2,t.state()),nil)
M.send(); input('old'); local oldstdout=stdout; exit(); flush(); eq(t.state(),nil)
vim.api.nvim_set_current_buf(target); P.open(); choose('Input'); input('restart')
oldstdout(42,{'stale','__CHAT_RESPONSE_DONE__',''}); flush(); assert(t.state()); terminal(); eq(t.state(),nil)
for _,lhs in ipairs({'ac','as','af','aF','ax','ab','aa','am','at','ak','ap','ae','ao'}) do assert(vim.fn.maparg('\\'..lhs,'n')~='') end
for _,lhs in ipairs({'as','ae','aa','ap'}) do assert(vim.fn.maparg('\\'..lhs,'x')~='') end
vim.fn.delete(dir,'rf')
print('chat and palette offline tests passed')
