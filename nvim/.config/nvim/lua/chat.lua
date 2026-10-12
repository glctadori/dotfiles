local M = {}
local buf, win, job, active, proposal
local editor_buf
local epoch = 0
local current_model = "deepseek/deepseek-v4.1-flash"
local current_thinking = "none"
local update_status
local ai_status = "Ready"
function M.status() return "AI: " .. ai_status end
function M.statusline()
  return active and active.sent and not active.cancelled and ("󰚩 " .. ai_status) or ""
end
local function set_status(status)
  if ai_status == status then return end
  ai_status = status
  if update_status then update_status() end
  vim.cmd("redrawstatus")
end
local wire = ""
local partial_line = false
local record_edit
local markers = { __CHAT_RESPONSE_DONE__ = "done", __CHAT_RESPONSE_ERROR__ = "error", __CHAT_RESPONSE_CANCELLED__ = "cancelled" }
local function warn(text) vim.notify("AI: " .. text, vim.log.levels.WARN) end
local function invalidate(silent)
  if proposal then
    local p=proposal
    proposal=nil
    p.valid = false
    if p.finish then p.finish(silent and "clear" or "rifiutata") end
    if p.close then p.close() end
  end
  proposal = nil
end
local function begin(kind)
  if active then warn("richiesta già in corso"); return end
  if not job and kind ~= "palette" then warn("chat non disponibile"); return end
  invalidate()
  active = { kind = kind, response = "", epoch = epoch }
  set_status("Choosing prompt...")
  return active
end
local function alive(r) return active == r and r.epoch == epoch end
local function cancel_input(r) if alive(r) then active = nil; set_status("Ready") end end
local function editable(b, path)
  return vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_is_loaded(b)
    and vim.api.nvim_buf_get_name(b) == path and vim.bo[b].buftype == ""
    and vim.bo[b].modifiable and not vim.bo[b].readonly and not vim.bo[b].binary
end
local function snapshot(c)
  local b = c.buf
  if b and not vim.api.nvim_buf_is_valid(b) then return end
  if b and vim.api.nvim_buf_get_name(b) ~= c.path then return end
  if not b then b = vim.fn.bufadd(c.path) end
  vim.fn.bufload(b)
  if not editable(b, c.path) then return end
  local text = table.concat(vim.api.nvim_buf_get_lines(b, 0, -1, false), "\n")
  if text:find("%z") then return end
  return { buf = b, path = c.path, text = text, tick = vim.api.nvim_buf_get_changedtick(b) }
end
local function unchanged(s)
  return editable(s.buf, s.path) and vim.api.nvim_buf_get_changedtick(s.buf) == s.tick
    and table.concat(vim.api.nvim_buf_get_lines(s.buf, 0, -1, false), "\n") == s.text
end
local function append(text)
  if not buf or not vim.api.nvim_buf_is_valid(buf) or text == "" then
    return
  end

  vim.bo[buf].modifiable = true

  local n = vim.api.nvim_buf_line_count(buf)
  local last = vim.api.nvim_buf_get_lines(buf, n - 1, n, false)[1] or ""

  local parts = vim.split(text, "\n", { plain = true })

  -- Primo pezzo continua la riga esistente
  vim.api.nvim_buf_set_lines(
    buf,
    n - 1,
    n,
    false,
    { last .. parts[1] }
  )

  -- Solo i newline reali creano nuove righe
  if #parts > 1 then
    vim.api.nvim_buf_set_lines(
      buf,
      -1,
      -1,
      false,
      vim.list_slice(parts, 2)
    )
  end

  vim.bo[buf].modifiable = false

  if win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
    vim.api.nvim_win_set_cursor(
      win,
      { vim.api.nvim_buf_line_count(buf), 0 }
    )
  end
end


local function show_diff(s, replacement, request)
  invalidate()
  local a, b = vim.fn.tempname(), vim.fn.tempname()
  local label=s.path ~= "" and s.path or "[No Name]"
  local ok, diff = pcall(function()
    vim.fn.writefile(vim.split(s.text, "\n", {plain=true}), a)
    vim.fn.writefile(vim.split(replacement, "\n", {plain=true}), b)
    local out = vim.fn.system({"diff", "-u", "--label", label, "--label", label .. " (AI)", a, b})
    return { text = out, code = vim.v.shell_error }
  end)
  vim.fn.delete(a); vim.fn.delete(b)
  if not ok or diff.code > 1 then
    set_status("Error: diff")
    if request then record_edit(request, "diff fallito") end
    warn("diff fallito"); return
  end
  if diff.code == 0 then
    set_status("Done: nessuna modifica")
    if request then record_edit(request, "nessuna modifica") end
    warn("nessuna modifica"); return
  end
  local p = { valid = true }; proposal = p
  set_status("Review: y applica / q rifiuta")
  local recorded = false
  p.finish = function(outcome)
    if recorded then return end
    recorded = true
    if outcome == "clear" then set_status("Ready")
    elseif outcome:find("invalidata", 1, true) then set_status("Invalidata: buffer cambiato")
    elseif outcome == "rifiutata" then set_status("Rifiutata")
    else set_status("Applicata al buffer") end
    if request and outcome ~= "clear" then record_edit(request, outcome) end
  end
  local db = vim.api.nvim_create_buf(false, true)
  vim.bo[db].bufhidden = "wipe"; vim.bo[db].filetype = "diff"
  vim.api.nvim_buf_set_lines(db, 0, -1, false, vim.split(diff.text, "\n", {plain=true}))
  vim.bo[db].modifiable = false
  vim.cmd("botright new")
  local dw = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(dw, db)
  vim.api.nvim_create_autocmd({"BufWipeout", "BufWinLeave"}, {buffer=db, once=true, callback=function()
    p.finish("rifiutata"); p.valid=false; if proposal==p then proposal=nil end
  end})
  local function close() if vim.api.nvim_win_is_valid(dw) then vim.api.nvim_win_close(dw, true) end end
  p.close=close
  vim.keymap.set("n", "q", close, {buffer=db, nowait=true})
  vim.keymap.set("n", "y", function()
    local valid = p.valid and unchanged(s)
    if not valid then p.finish("invalidata: buffer cambiato"); close(); warn("file cambiato, modifica annullata"); return end
    vim.api.nvim_buf_set_lines(s.buf, 0, -1, false, vim.split(replacement, "\n", {plain=true}))
    p.finish("applicata al buffer, non salvata")
    close()
    vim.notify("AI: modifica applicata al buffer")
  end, {buffer=db, nowait=true})
end
local function replacement(text, response)
  local json = response:match("^%s*(.-)%s*$")
  if json:sub(1,3) == "```" then
    json = json:match("^```json%s*\n(.-)\n```%s*$")
    if not json then return nil end
  end
  local ok, obj = pcall(vim.json.decode, json)
  if not ok or type(obj) ~= "table" then return end
  if type(obj.replacement) == "string" then
    for k in pairs(obj) do if k ~= "replacement" then return end end
    if obj.replacement:find("%z") then return end
    return obj.replacement
  end
  if type(obj.edits) ~= "table" or not vim.islist(obj.edits) or #obj.edits == 0 then return end
  for k in pairs(obj) do if k ~= "edits" then return end end
  local ranges = {}
  for _, e in ipairs(obj.edits) do
    if type(e) ~= "table" or type(e.old_text) ~= "string" or e.old_text == "" or type(e.new_text) ~= "string" or e.new_text:find("%z") then return end
    for k in pairs(e) do if k ~= "old_text" and k ~= "new_text" then return end end
    local first, last = text:find(e.old_text, 1, true)
    if not first or text:find(e.old_text, first+1, true) then return end
    ranges[#ranges+1] = {first=first, last=last, new=e.new_text}
  end
  table.sort(ranges, function(a,b) return a.first < b.first end)
  for i=2,#ranges do if ranges[i].first <= ranges[i-1].last then return end end
  for i=#ranges,1,-1 do local e=ranges[i]; text=text:sub(1,e.first-1)..e.new..text:sub(e.last+1) end
  return text
end
function M.apply()
  warn("usa <leader>aa per richiedere una proposta")
end
local function finish(kind)
  local r = active
  if not r or not r.sent then return end
  active = nil
  set_status((kind == "cancelled" or r.cancelled) and "Cancelled"
    or kind == "done" and "Done" or "Error")
  if kind == "done" and not r.cancelled and not r.cleared and vim.fn.executable("notify-send") == 1 then
    vim.fn.jobstart({"notify-send", "--app-name=Neovim", "Neovim · AI",
      r.snapshot and "Elaborazione completata: proposta di modifica pronta." or "Risposta completata."}, {detach=true})
  end
  if r.snapshot and not r.cleared then
    local status = (kind == "cancelled" or r.cancelled) and "annullata"
      or kind == "done" and "completata" or "generazione fallita"
    append("\nModifica AI: " .. status .. "\n")
  end
  if kind == "done" and not r.cancelled and r.snapshot then
    if not unchanged(r.snapshot) then set_status("Invalidata: buffer cambiato"); record_edit(r, "invalidata: buffer cambiato"); warn("file cambiato, proposta annullata"); return end
    local result = replacement(r.target_text or r.snapshot.text, r.response)
    if result then
      r.proposed = result
      if r.range then
        local lines = vim.split(r.snapshot.text, "\n", {plain=true})
        local a, z = r.range.first, r.range.last
        local start = a[2]
        local stop = z[2]
        for i=1,a[1] do start=start+#lines[i]+1 end
        for i=1,z[1] do stop=stop+#lines[i]+1 end
        result = r.snapshot.text:sub(1,start) .. result .. r.snapshot.text:sub(stop+1)
      end
      show_diff(r.snapshot, result, r)
    else set_status("Error: proposta non valida"); record_edit(r, "proposta non valida"); warn("proposta non valida") end
  elseif r.snapshot then
    record_edit(r, (kind == "cancelled" or r.cancelled) and "annullata" or "generazione fallita")
  end
end
-- Keep only a possible reserved marker prefix; ordinary text streams immediately.
local function emit(text)
  if not (active and (active.cleared or active.snapshot)) then append(text) end
  if active and active.sent and not active.cancelled then
    if text:find("%S") then set_status(active.snapshot and "Editing..." or "Responding...") end
    active.response = active.response .. text
  end
end
local function consume(chunk)
  wire = wire .. chunk
  while true do
    local n = wire:find("\n", 1, true)
    if not n then break end
    local line = wire:sub(1, n - 1)
    wire = wire:sub(n + 1)
    if not partial_line and markers[line] then finish(markers[line])
    else emit(line .. "\n") end
    partial_line = false
  end
  if wire ~= "" then
    local possible = false
    if not partial_line then
      for marker in pairs(markers) do
        if marker:sub(1, #wire) == wire then possible = true; break end
      end
    end
    if not possible then emit(wire); wire = ""; partial_line = true end
  end
end
local function start_chat()
  if job then return end
  epoch=epoch+1; local generation=epoch
  if active and not active.sent then active.epoch=epoch end
  job=vim.fn.jobstart({"chat", "--pipe"}, {
    stdin="pipe",
    on_stdout=function(_,data) if data then local chunk=table.concat(data,"\n"); vim.schedule(function() if generation==epoch then consume(chunk) end end) end end,
    on_stderr=function(_,data) if data then local text=table.concat(data,"\n"); vim.schedule(function() if generation==epoch and text~="" then warn(text) end end) end end,
    on_exit=function() vim.schedule(function() if generation==epoch then job=nil; active=nil; wire=""; partial_line=false; epoch=epoch+1; invalidate(); set_status("Disconnected"); warn("processo chat terminato") end end) end,
  })
  if job <= 0 then job=nil; set_status("Error: avvio chat"); warn("avvio chat fallito")
  else vim.fn.chansend(job, vim.json.encode({type="config", model=current_model, reasoning=current_thinking}) .. "\n") end
end
local function send(r, request, input)
  if not alive(r) then return end
  r.sent=true
  set_status("Thinking...")
  if r.snapshot then
    append("\n## Richiesta di modifica\n\n" .. (r.source_name or r.snapshot.path)
      .. "\n\n" .. input .. "\n\nRichiesta AI in corso; la proposta apparirà nel diff.\n")
  else
    append("\n## Me\n\n" .. input .. "\n\n## Assistant\n")
  end
  local ok, count = pcall(vim.fn.chansend, job, vim.json.encode(request).."\n")
  if not ok or count == 0 then r.sent=false; active=nil; set_status("Error: invio"); warn("invio fallito") end
end
function M.send()
  local r=begin("message"); if not r then return end
  vim.ui.input({prompt="You: "}, function(input)
    if not alive(r) then return end
    if not input or input=="" then cancel_input(r); return end
    send(r,{type="message",text=input},input)
  end)
end
function M.toggle()
  if win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) ~= buf then win=nil end
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
    win = nil
    return
  end

  -- Ricorda dove stavo lavorando
  local previous_win = vim.api.nvim_get_current_win()
  local previous_buf = vim.api.nvim_get_current_buf()
  if vim.bo[previous_buf].buftype == "" then editor_buf=previous_buf end

  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    buf = vim.api.nvim_create_buf(false, true)

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "markdown"

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "# Chat",
      "",
    })

    update_status()

    vim.bo[buf].modifiable = false
  end

  vim.cmd("botright vsplit")
  win = vim.api.nvim_get_current_win()

  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_width(win, 60)

  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].breakindent = true
  vim.wo[win].winbar = "%{%v:lua.require'chat'.status()%}"

  start_chat()

  -- Torna al buffer/finestra precedente
  if vim.api.nvim_win_is_valid(previous_win) then
    vim.api.nvim_set_current_win(previous_win)
  end
end


-- Source capture happens before opening any picker or chat window.
function M.origin()
  local b=vim.api.nvim_get_current_buf()
  if vim.bo[b].buftype == "" then editor_buf=b; return b end
  local previous=vim.fn.win_getid(vim.fn.winnr("#"))
  if previous ~= 0 and vim.api.nvim_win_is_valid(previous) then
    local candidate=vim.api.nvim_win_get_buf(previous)
    if vim.bo[candidate].buftype == "" then editor_buf=candidate end
  end
  if editor_buf and vim.api.nvim_buf_is_valid(editor_buf) then return editor_buf end
  return b
end
function M.project_root(b)
  local file = vim.api.nvim_buf_get_name(b or 0)
  local start = file ~= "" and vim.fs.dirname(file) or vim.fn.getcwd()
  return vim.fs.root(start, {".git", "pyproject.toml", "platformio.ini", "CMakeLists.txt"}) or start
end

local binary_extensions = {"pdf", "png", "jpg", "jpeg", "webp", "gif", "bmp", "zip", "gz", "exe", "so"}
local function textual(text)
  if text:find("[%z\1-\8\11\14-\31\127]") then return false end
  local ok, encoded = pcall(vim.fn.iconv, text, "utf-8", "utf-16le")
  return ok and vim.fn.iconv(encoded, "utf-16le", "utf-8") == text
end
function M.source(c)
  local b, path = c.buf, c.path
  if b then
    if not vim.api.nvim_buf_is_valid(b) or not vim.api.nvim_buf_is_loaded(b) then return nil, "buffer non disponibile" end
    path = vim.api.nvim_buf_get_name(b)
  else
    path = vim.fn.fnamemodify(path, ":p")
    local existing = vim.fn.bufnr(path)
    if existing ~= -1 and vim.api.nvim_buf_is_loaded(existing) then b=existing end
  end
  if vim.tbl_contains(binary_extensions, vim.fn.fnamemodify(path, ":e"):lower()) then return nil, "file binario" end
  local text
  if b then
    if vim.bo[b].binary then return nil, "buffer binario" end
    text = table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false), "\n")
  else
    local uv = vim.uv
    local fd = uv.fs_open(path, "r", 438)
    if not fd then return nil, "file non leggibile" end
    local stat = uv.fs_fstat(fd)
    if stat and stat.type == "file" then text=uv.fs_read(fd,stat.size,0) end
    uv.fs_close(fd)
    if not text then return nil, "file non leggibile" end
  end
  if not textual(text) then return nil, "sorgente binaria o non UTF-8" end
  return {buf=b, path=path, name=path ~= "" and path or "[No Name]", text=text,
    tick=b and vim.api.nvim_buf_get_changedtick(b)}
end

function M.selection()
  local b = vim.api.nvim_get_current_buf()
  local mode = vim.fn.mode()
  local live = mode == "v" or mode == "V" or mode == "\22"
  local kind = live and mode or vim.fn.visualmode()
  if kind == "\22" then return nil, "Visual block non supportato: usa v o V" end
  local a = vim.fn.getpos(live and "v" or "'<")
  local z = vim.fn.getpos(live and "." or "'>")
  local backwards = a[2] > z[2] or (a[2] == z[2] and a[3] > z[3])
  if backwards then a,z=z,a end
  local sr,er = a[2]-1,z[2]-1
  if sr < 0 or er >= vim.api.nvim_buf_line_count(b) then return nil, "selezione non disponibile" end
  local lines = vim.api.nvim_buf_get_lines(b,sr,er+1,false)
  local sc,ec = math.min(a[3]-1,#lines[1]),math.min(z[3]-1,#lines[#lines])
  local function after_char(line,col)
    if col >= #line then return #line end
    local n = line:byte(col+1)
    return math.min(#line,col+(n<128 and 1 or n<224 and 2 or n<240 and 3 or 4))
  end
  if kind == "V" then sc,ec=0,#lines[#lines]
  elseif vim.o.selection == "exclusive" and (sr ~= er or sc ~= ec) then
    -- Vim excludes the upper endpoint, including reversed selections.
  else ec=after_char(lines[#lines],ec) end
  local source, err = M.source({buf=b})
  if not source then return nil,err end
  source.range={first={sr,sc},last={er,ec}}
  source.text=table.concat(vim.api.nvim_buf_get_text(b,sr,sc,er,ec,{}), "\n")
  source.name=source.name .. " (selection)"
  if live then vim.cmd("normal! \27") end
  return source
end

record_edit = function(r, outcome)
  if not r.contextual or r.epoch ~= epoch or not job or r.cleared then return end
  local note = "Esito modifica di " .. (r.source_name or r.snapshot.path) .. ": " .. outcome
    .. "\nRichiesta: " .. (r.instruction or "")
  if r.proposed then note = note .. "\nTesto proposto (applicato soltanto se indicato nell'esito):\n" .. r.proposed end
  local ok,count=pcall(vim.fn.chansend,job,vim.json.encode({type="note",text=note}) .. "\n")
  if not ok or count == 0 then warn("registrazione esito fallita"); return end
  append("\n## Edit\n\n" .. (r.source_name or r.snapshot.path) .. " — " .. outcome .. "\n")
end

function M.settings() return {model=current_model,reasoning=current_thinking} end
function M.begin_request() return begin("palette") end
function M.request_alive(r) return alive(r) end
function M.cancel_request(r) cancel_input(r) end
function M.target(source)
  local ok,s = pcall(snapshot,source)
  if not ok or not s then return nil,"target non modificabile" end
  if source.tick and source.tick ~= s.tick then return nil,"buffer cambiato durante la scelta" end
  source.snapshot=s
  source.buf=s.buf
  if not source.range then source.text=s.text end
  return source
end
function M.execute(r, sources, instruction, opts)
  if not alive(r) then return end
  opts=opts or {}
  local source=sources and sources[1]
  if opts.edit then
    if not source or #sources ~= 1 or not source.snapshot then cancel_input(r); warn("scegli un unico target modificabile"); return end
    if not unchanged(source.snapshot) then cancel_input(r); warn("buffer cambiato, richiesta annullata"); return end
    r.snapshot=source.snapshot; r.range=source.range; r.target_text=source.text
    r.contextual=opts.contextual; r.source_name=source.name; r.instruction=instruction
  end
  if not win or not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= buf then
    M.toggle()
  else start_chat() end
  if not job then cancel_input(r); return end
  local request={model=opts.model,reasoning=opts.reasoning,web=opts.web}
  if not source then request.type="message"; request.text=instruction
  else
    local parts={}
    for _,c in ipairs(sources) do parts[#parts+1]="SOURCE: "..c.name.."\n"..c.text end
    request.type="context"; request.name=source.name; request.text=table.concat(parts,"\n\n---\n\n")
    request.prompt=instruction
  end
  if opts.edit then
    request.history="readonly"; request.use_history=opts.contextual == true
    request.text=source.text
    request.prompt=[=[Modifica soltanto il target fornito seguendo la richiesta. Restituisci esclusivamente JSON valido:
{"edits":[{"old_text":"testo esatto","new_text":"sostituzione"}]} oppure {"replacement":"intero testo sostitutivo"}.
Ogni old_text deve essere non vuoto, unico nel target e non sovrapposto. Nessun percorso, campo extra o spiegazione. Il target può essere una selezione: non modificare testo esterno. Usa il target aggiornato di questo turno.
RICHIESTA:
]=]..instruction
  end
  local display=opts.web and ("🌐 Cerca sul web: "..instruction) or instruction
  if source and not opts.edit then
    display=request.text .. "\n\nRichiesta:\n" .. instruction
  end
  send(r,request,display)
end

-- Compatibility shortcuts share the same source and request pipeline.
function M.file(global) require("palette").send_source(global and "Files global" or "Files root", true) end
function M.buffer() require("palette").send_source("Buffers", true) end
function M.visual()
  local source,err=M.selection()
  if not source then warn(err); return end
  local r=M.begin_request(); if not r then return end
  M.execute(r,{},source.text)
end
function M.edit() require("palette").open("isolated", true) end
function M.request_apply() require("palette").open("contextual") end
function M.stop()
  invalidate()
  local r=active; if not r then return end
  r.cancelled=true
  if not r.sent then
    active=nil
    set_status("Cancelled")
    if r.picker and not r.picker.closed then r.picker:close() end
  elseif job then set_status("Stopping..."); vim.fn.chansend(job,vim.json.encode({type="cancel"}).."\n") end
end
function M.clear()
  invalidate(true)
  M.stop()
  if not active then set_status("Ready") end
  if active then active.cleared=true end
  if job then vim.fn.chansend(job,vim.json.encode({type="clear"}).."\n") end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.bo[buf].modifiable=true
    vim.api.nvim_buf_set_lines(buf,0,-1,false,{"# Chat",""})
    update_status(); vim.bo[buf].modifiable=false
  end
end
M._test = { replacement=replacement, consume=consume, snapshot=snapshot, unchanged=unchanged, state=function() return active,proposal end }
update_status = function()
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

  local status = "Model: " .. current_model
      .. " · Thinking: " .. current_thinking
      .. " · " .. M.status()

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  local index = nil
  for i, line in ipairs(lines) do
    if line:match("^Model: ") then
      index = i - 1
      break
    end
  end

  local was_modifiable = vim.bo[buf].modifiable
  vim.bo[buf].modifiable = true

  if index then
    vim.api.nvim_buf_set_lines(buf, index, index + 1, false, { status })
  else
    vim.api.nvim_buf_set_lines(buf, 1, 1, false, { status, "" })
  end

  vim.bo[buf].modifiable = was_modifiable
end

function M.model()
  local generation=epoch
  local models = {
    "deepseek/deepseek-v4.1-flash",
    "openai/gpt-6.1-sol",
  }

  vim.ui.select(models, {
    prompt = "AI model:",
  }, function(choice)
    if not choice or generation ~= epoch then return end

    current_model = choice
    update_status()
    if job then vim.fn.chansend(job, vim.json.encode({type="config",model=choice}) .. "\n") end

    vim.notify("AI model: " .. choice)
  end)
end

function M.thinking()
  local generation=epoch
  vim.ui.select({
    "none", "low", "medium", "high",
  }, {
    prompt = "AI thinking:",
  }, function(choice)
    if not choice or generation ~= epoch then return end

    current_thinking = choice
    update_status()


    if job then vim.fn.chansend(job, vim.json.encode({type="config",reasoning=choice}) .. "\n") end

    vim.notify("AI thinking: " .. choice)
  end)
end

vim.keymap.set("n", "<leader>ak", function()
  M.stop()
end, { desc = "AI stop" })

vim.keymap.set("n", "<leader>ac", function()
  M.toggle()
end, { desc = "AI chat" })

vim.keymap.set("n", "<leader>as", function()
  M.send()
end, { desc = "AI send" })

vim.keymap.set("n", "<leader>af", function()
  require("chat").file(false)
end, { desc = "AI files (project)" })

vim.keymap.set("n", "<leader>aF", function()
  require("chat").file(true)
end, { desc = "AI files (global)" })

vim.keymap.set("n", "<leader>ax", function()
  M.clear()
end, { desc = "AI clear chat" })

vim.keymap.set("n", "<leader>ab", function()
  require("chat").buffer()
end, { desc = "AI buffers" })

vim.keymap.set("x", "<leader>as", function()
  M.visual()
end, { desc = "AI send selection only" })

vim.keymap.set({"n", "x"}, "<leader>ae", function()
  require("palette").open("isolated", vim.fn.mode() ~= "n")
end, { desc = "AI edit without context" })

vim.keymap.set({"n", "x"}, "<leader>aa", function()
  require("palette").open("contextual", vim.fn.mode() ~= "n")
end, { desc = "AI edit from chat" })

vim.keymap.set("n", "<leader>am", function()
  require("chat").model()
end, { desc = "AI model" })

vim.keymap.set("n", "<leader>at", function()
  require("chat").thinking()
end, { desc = "AI thinking" })

return M
