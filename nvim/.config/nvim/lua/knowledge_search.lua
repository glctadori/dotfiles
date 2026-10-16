local M = {}
local last_results
local request_id = 0

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Ricerca conoscenza" })
end

local history_path = vim.fn.stdpath("state") .. "/knowledge-search/history.json"

local function valid_results(results)
  if type(results) ~= "table" or (results.corpus ~= "wiki" and results.corpus ~= "library")
    or type(results.query) ~= "string" or type(results.hits) ~= "table"
    or not vim.islist(results.hits) then return false end
  for _, hit in ipairs(results.hits) do
    if type(hit) ~= "table" or type(hit.path) ~= "string" or type(hit.text) ~= "string"
      or type(hit[results.corpus == "wiki" and "line" or "page"]) ~= "number"
      or type(hit.score) ~= "number" then return false end
  end
  return true
end

local function read_history()
  if vim.fn.filereadable(history_path) ~= 1 then return {} end
  local ok, entries = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(history_path), "\n"))
  end)
  if ok and type(entries) == "table" and vim.islist(entries) then
    for _, entry in ipairs(entries) do
      if not valid_results(entry) or type(entry.timestamp) ~= "number" then ok = false; break end
    end
  else
    ok = false
  end
  if not ok then
    notify("Cronologia non leggibile: " .. history_path, vim.log.levels.WARN)
    return {}
  end
  return entries
end

local function save_results(results)
  local entries = read_history()
  table.insert(entries, 1, results)
  while #entries > 50 do table.remove(entries) end
  local temporary = history_path .. "." .. vim.fn.getpid() .. ".tmp"
  local ok, err = pcall(function()
    vim.fn.mkdir(vim.fs.dirname(history_path), "p")
    if vim.fn.writefile({ vim.json.encode(entries) }, temporary) ~= 0 then
      error("scrittura fallita")
    end
    local renamed, rename_error = vim.uv.fs_rename(temporary, history_path)
    if not renamed then error(rename_error) end
  end)
  if not ok then
    vim.uv.fs_unlink(temporary)
    notify("Impossibile salvare la cronologia: " .. tostring(err), vim.log.levels.WARN)
  end
end

function M.history()
  local entries = read_history()
  if #entries == 0 then return notify("Nessuna ricerca salvata") end
  local items = {}
  for _, entry in ipairs(entries) do
    items[#items + 1] = {
      text = ("%s — %s — %s (%d risultati)"):format(
        os.date("%Y-%m-%d %H:%M", entry.timestamp), entry.corpus,
        entry.query:gsub("%s+", " "), #entry.hits),
      results = entry,
      preview = { text = entry.query, ft = "text", loc = false },
    }
  end
  Snacks.picker({
    title = "Cronologia ricerca conoscenza",
    items = items,
    format = "text",
    preview = "preview",
    confirm = function(picker, item)
      if not item then return end
      picker:close()
      last_results = item.results
      M.show(item.results)
    end,
  })
end

function M.selection()
  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" and mode ~= "\22" then return nil end
  local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), {
    type = mode, exclusive = vim.o.selection == "exclusive",
  })
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  return vim.trim(table.concat(lines, "\n"))
end

function M.show(results)
  results = results or last_results or read_history()[1]
  if results then last_results = results end
  if not results then return notify("Nessuna ricerca precedente") end
  if #results.hits == 0 then return notify("Nessun risultato: " .. results.query) end
  local items = {}
  for _, hit in ipairs(results.hits) do
    items[#items + 1] = {
      text = ("%s — %s %d — %.3f"):format(vim.fs.basename(hit.path),
        results.corpus == "wiki" and "riga" or "PDF p.", hit.line or hit.page, hit.score),
      file = hit.path,
      page = hit.page,
      line = hit.line,
      pos = hit.line and { hit.line, 0 } or nil,
      preview = { text = hit.text, ft = "text", loc = false },
    }
  end
  Snacks.picker({
    title = results.corpus .. ": " .. results.query,
    items = items,
    format = "text",
    preview = "preview",
    confirm = function(picker, item)
      if not item then return end
      if vim.fn.filereadable(item.file) ~= 1 then
        return notify("File non disponibile: " .. item.file, vim.log.levels.ERROR)
      end
      if results.corpus == "wiki" then
        return Snacks.picker.actions.jump(picker, item)
      end
      if vim.fn.executable("xdg-open") ~= 1 then
        return notify("xdg-open non disponibile", vim.log.levels.ERROR)
      end
      local job = vim.fn.jobstart({ "xdg-open", item.file }, { detach = true })
      if job <= 0 then return notify("Impossibile avviare xdg-open", vim.log.levels.ERROR) end
      picker:close()
    end,
  })
end

function M.run(corpus, query)
  if vim.fn.executable("semantic-search") ~= 1 then
    return notify("semantic-search non disponibile", vim.log.levels.ERROR)
  end
  request_id = request_id + 1
  local id = request_id
  notify("Ricerca in " .. corpus .. "…")
  vim.system({ "semantic-search", "--format", "json", "-k", "12", corpus, query },
    { text = true }, function(result)
      vim.schedule(function()
        if id ~= request_id then return end
        if result.code ~= 0 then
          return notify(vim.trim(result.stderr or "") ~= "" and vim.trim(result.stderr)
            or "Ricerca fallita", vim.log.levels.ERROR)
        end
        local ok, hits = pcall(vim.json.decode, result.stdout)
        if not ok or type(hits) ~= "table" or not vim.islist(hits) then
          return notify("Risposta JSON non valida", vim.log.levels.ERROR)
        end
        local results = { corpus = corpus, query = query, hits = hits, timestamp = os.time() }
        if not valid_results(results) then
          return notify("Risultato non valido", vim.log.levels.ERROR)
        end
        last_results = results
        save_results(results)
        if #hits == 0 then return notify("Nessun risultato") end
        M.show(last_results)
      end)
    end)
end

function M.search(corpus)
  local selected = M.selection()
  local function choose(query)
    query = vim.trim(query or "")
    if query == "" then return end
    M.run(corpus or "wiki", query)
  end
  if selected and selected ~= "" then
    vim.schedule(function() choose(selected) end)
  else
    vim.ui.input({ prompt = "Cerca > " }, choose)
  end
end

return M
