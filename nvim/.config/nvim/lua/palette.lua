local M = {}
local chat = require("chat")
local profiles = {
  rapido = { model = "deepseek/deepseek-v4.1-flash", reasoning = "none" },
  frontier = { model = "openai/gpt-6.1-sol", reasoning = "high" },
}
local levels = { "none", "low", "medium", "high" }
local function warn(message) vim.notify("AI: " .. message, vim.log.levels.WARN) end
local function later(fn) vim.schedule(function() vim.schedule(fn) end) end
local function alive(r) return chat.request_alive(r) end
local function cancel(r) chat.cancel_request(r) end

local function parse(text)
  text = text:gsub("\r\n", "\n")
  local meta = {}
  if text:match("^%-%-%-\n") then
    local header, body = text:match("^%-%-%-\n(.-)\n%-%-%-\n?(.*)$")
    if not header then return nil, "frontmatter non chiuso" end
    for line in (header .. "\n"):gmatch("(.-)\n") do
      if vim.trim(line) ~= "" then
        local key, value = line:match("^([%w_]+):%s*(.-)%s*$")
        if not key or (key ~= "profile" and key ~= "thinking") or meta[key] then
          return nil, "metadati ammessi: profile e thinking, una volta ciascuno"
        end
        if value:match('^".*"$') or value:match("^'.*'$") then value = value:sub(2,-2) end
        meta[key] = value
      end
    end
    text = body
  end
  if meta.profile and not profiles[meta.profile] then return nil, "profilo sconosciuto: " .. meta.profile end
  if meta.thinking and not vim.tbl_contains(levels, meta.thinking) then return nil, "thinking non valido: " .. meta.thinking end
  if vim.trim(text) == "" then return nil, "prompt vuoto" end
  local title
  for line in (text .. "\n"):gmatch("(.-)\n") do
    title = line:match("^#%s+(.+)")
    if title then title=title:gsub("%s+#+%s*$", ""); break end
  end
  return {text=text, title=title, profile=meta.profile, thinking=meta.thinking}
end

local function effective(prompt, overrides)
  local defaults = chat.settings()
  local profile = prompt and prompt.profile and profiles[prompt.profile] or {}
  return {
    model = overrides.model or profile.model or defaults.model,
    reasoning = overrides.reasoning or (prompt and prompt.thinking) or profile.reasoning or defaults.reasoning,
  }
end

local function wiki_root(b)
  local file = vim.api.nvim_buf_get_name(b)
  local fallback, best
  for _,wiki in ipairs(vim.g.vimwiki_list or {}) do
    if wiki.syntax == "markdown" then
      local path = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(wiki.path), ":p")):gsub("/$", "")
      fallback = fallback or path
      if file:sub(1,#path+1) == path .. "/" and (not best or #path > #best) then best=path end
    end
  end
  return best or fallback
end

local function prompts(b)
  local items = {{text="New", new=true}}
  local root = wiki_root(b)
  if not root then return items end
  local paths = vim.fn.globpath(root, "prompt-*.md", false, true)
  table.sort(paths)
  for _,path in ipairs(paths) do
    if vim.fn.isdirectory(path) == 0 then
      local source = chat.source({path=path})
      local prompt = source and parse(source.text)
      local name = vim.fn.fnamemodify(path, ":t"):gsub("^prompt%-", ""):gsub("%.md$", "")
      items[#items+1] = {text=prompt and prompt.title or name, file=path, prompt=prompt}
    end
  end
  return items
end

-- Confirm and cancellation are exclusive, even though Snacks closes asynchronously.
local function pick(r, items, title, cb)
  local confirmed = false
  r.picker=Snacks.picker({items=items, title=title, format="text", layout={preset="select"},
    sort={fields={"score:desc", "idx"}}, matcher={sort_empty=false},
    confirm=function(picker,item)
      confirmed=true; picker:close()
      later(function() if alive(r) then if item then cb(item) else cancel(r) end end end)
    end,
    on_close=function() if not confirmed then cancel(r) end end,
  })
end

local function choose_sources(r, kind, cwd, single, cb)
  if kind == "Current buffer" then
    local source,err=chat.source({buf=r.origin})
    if not source then cancel(r); warn(err); return end
    cb({source}); return
  end
  local confirmed = false
  local opts = {
    title=single and "AI: target autorizzato" or "AI: sorgenti (Tab seleziona, Invio conferma)",
    on_close=function() if not confirmed then cancel(r) end end,
    confirm=function(picker,item)
      local selected=picker:selected()
      if #selected == 0 and item then selected={item} end
      confirmed=true; picker:close()
      later(function()
        if not alive(r) then return end
        if #selected == 0 then cancel(r); return end
        if single and #selected ~= 1 then cancel(r); warn("Edit richiede un unico target"); return end
        local sources,seen={},{}
        for _,entry in ipairs(selected) do
          local c
          if kind == "Buffers" then c={buf=entry.buf}
          else
            local path=Snacks.picker.util.path(vim.tbl_extend("force", {cwd=cwd}, entry))
            if path then c={path=path} end
          end
          local source,err
          if c then source,err=chat.source(c) end
          if not source then cancel(r); warn(err or "sorgente non disponibile"); return end
          local key=source.buf or source.path
          if not seen[key] then sources[#sources+1]=source; seen[key]=true end
        end
        cb(sources)
      end)
    end,
  }
  if kind == "Buffers" then r.picker=Snacks.picker.buffers(opts)
  else opts.cwd=cwd; r.picker=Snacks.picker.files(opts) end
end

local function instruction(r, sources, mode, direct)
  local overrides={}
  local function execute(text, prompt)
    if not alive(r) then return end
    if not text or vim.trim(text) == "" then cancel(r); return end
    local opts=effective(prompt,overrides)
    opts.edit=mode ~= "chat"; opts.contextual=mode == "contextual"
    chat.execute(r,sources,text,opts)
  end
  if direct then
    vim.ui.input({prompt="You: "}, function(text) execute(text) end)
    return
  end
  local confirmed=false
  local items=prompts(r.origin)
  if mode == "chat" and #sources == 1 and sources[1].range then
    table.insert(items,2,{text="Solo selezione", selection_only=true})
  end
  local function read_prompt(item)
    if not item or item.new then return nil end
    local source,err=chat.source({path=item.file})
    if not source then return nil,err end
    return parse(source.text)
  end
  local function title(picker,item)
    local values=effective(item and item.prompt,overrides)
    picker.title="AI prompts · "..values.model.." · "..values.reasoning.." | C-Enter/C-e: +istruzione · A-m/A-t: modello/thinking"
    picker:update_titles()
  end
  local function confirm(picker,item,extra)
    if not alive(r) then picker:close(); return end
    if not item then return end
    if item.selection_only then
      confirmed=true; picker:close()
      later(function()
        if alive(r) then chat.execute(r,{},sources[1].text,effective(nil,overrides)) end
      end)
      return
    end
    local prompt,err=read_prompt(item)
    if not item.new and not prompt then warn(err); return end
    confirmed=true; picker:close()
    later(function()
      if not alive(r) then return end
      if item.new then
        vim.ui.input({prompt="AI prompt: "}, function(text) execute(text) end)
      elseif extra then
        vim.ui.input({prompt="Istruzione aggiuntiva (facoltativa): "}, function(text)
          if not alive(r) then return end
          if text == nil then cancel(r); return end
          execute(prompt.text .. (vim.trim(text) ~= "" and "\n\n"..text or ""),prompt)
        end)
      else execute(prompt.text,prompt) end
    end)
  end
  r.picker=Snacks.picker({items=items, title="AI prompts", format="text", layout={preset="select"}, auto_close=false,
    sort={fields={"score:desc", "idx"}}, matcher={sort_empty=false},
    on_show=function(picker) title(picker,picker:current()) end,
    on_change=title,
    on_close=function() if not confirmed then cancel(r) end end,
    confirm=function(picker,item) confirm(picker,item,false) end,
    actions={
      with_instruction=function(picker) confirm(picker,picker:current(),true) end,
      request_model=function(picker)
        vim.ui.select({profiles.rapido.model,profiles.frontier.model},{prompt="Modello per questa richiesta:"},function(choice)
          if alive(r) and not picker.closed then overrides.model=choice or overrides.model; title(picker,picker:current()) end
        end)
      end,
      request_thinking=function(picker)
        vim.ui.select(levels,{prompt="Thinking per questa richiesta:"},function(choice)
          if alive(r) and not picker.closed then overrides.reasoning=choice or overrides.reasoning; title(picker,picker:current()) end
        end)
      end,
    },
    win={input={keys={
      ["<C-CR>"]={"with_instruction",mode={"n","i"}},
      ["<C-e>"]={"with_instruction",mode={"n","i"}},
      ["<M-m>"]={"request_model",mode={"n","i"}},
      ["<M-t>"]={"request_thinking",mode={"n","i"}},
    }}},
  })
end

local function prepare(r,sources,mode,direct)
  if mode ~= "chat" then
    if #sources ~= 1 then cancel(r); warn("Edit richiede un unico target"); return end
    local target,err=chat.target(sources[1])
    if not target then cancel(r); warn(err); return end
  end
  instruction(r,sources,mode,direct)
end

function M.open(mode, visual, direct)
  mode=mode or "chat"
  local origin=chat.origin()
  local source,err
  if visual then source,err=chat.selection() end
  if visual and not source then warn(err); return end
  local r=chat.begin_request(); if not r then return end
  r.origin=origin; r.root=chat.project_root(origin)
  if source then prepare(r,{source},mode,direct); return end
  if mode == "isolated" then
    choose_sources(r,"Current buffer",nil,true,function(sources) prepare(r,sources,mode,direct) end)
    return
  end
  local items={}
  if mode == "chat" then
    items[#items+1]={text="Input"}
    items[#items+1]={text="Cerca sul web"}
  end
  for _,name in ipairs({"Current buffer","Files root","Files global","Buffers"}) do items[#items+1]={text=name} end
  pick(r,items,mode == "chat" and "AI: Send to Chat" or "AI: scegli il target",function(item)
    if item.text == "Input" then instruction(r,{},mode,true); return end
    if item.text == "Cerca sul web" then M.web(r); return end
    local cwd=item.text == "Files global" and vim.fn.expand("~") or r.root
    choose_sources(r,item.text,cwd,mode ~= "chat",function(sources) prepare(r,sources,mode,direct) end)
  end)
end

function M.send_source(kind, direct)
  local r=chat.begin_request(); if not r then return end
  r.origin=chat.origin(); r.root=chat.project_root(r.origin)
  local cwd=kind == "Files global" and vim.fn.expand("~") or r.root
  choose_sources(r,kind,cwd,false,function(sources) prepare(r,sources,"chat",direct) end)
end

function M.web(r)
  r=r or chat.begin_request(); if not r then return end
  vim.ui.input({prompt="Cerca sul web: "},function(text)
    if not chat.request_alive(r) then return end
    if not text or not text:match("%S") then chat.cancel_request(r); return end
    chat.execute(r,{},text,{web=true})
  end)
end

function M.controls()
  local values=chat.settings()
  vim.ui.select({"Toggle chat", "Cerca sul web", "Model", "Thinking", "Stop", "Clear"},
    {prompt="AI controls · "..values.model.." · "..values.reasoning},function(choice)
      local actions={ ["Toggle chat"]=chat.toggle, ["Cerca sul web"]=M.web, Model=chat.model, Thinking=chat.thinking, Stop=chat.stop, Clear=chat.clear }
      if actions[choice] then actions[choice]() end
    end)
end

vim.keymap.set({"n","x"}, "<leader>ap", function() M.open("chat",vim.fn.mode() ~= "n") end, {desc="AI Send to Chat"})
vim.keymap.set("n", "<leader>ao", M.controls, {desc="AI controls"})
M._test={parse=parse,effective=effective,prompts=prompts,wiki_root=wiki_root}
return M
