local M = {}

function M.setup_highlights()
  local function apply()
    local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
    vim.api.nvim_set_hl(0, "ClaudeTerminal", { fg = normal.fg, bg = "NONE", ctermbg = "NONE" })
  end
  apply()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("ClaudeTerminalHighlights", { clear = true }),
    callback = apply,
  })
end

local function warn(message)
  vim.notify(message, vim.log.levels.WARN, { title = "Claude Code" })
end

-- Stato della sessione: gli hook (claude-nvim-state) scrivono un file nella home,
-- condivisa con la sandbox; qui lo osserviamo e lo mostriamo in statusline.
local state_dir = vim.fn.stdpath("state") .. "/claude"
local state_file = state_dir .. "/" .. vim.fn.getpid() .. ".json"
local current = { state = "off" }
local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local frame, timer, watcher = 1, nil, nil

function M.state_path() return state_file end

local function in_claude_window()
  local buf = require("claudecode.terminal").get_active_terminal_bufnr()
  return buf ~= nil and vim.api.nvim_get_current_buf() == buf
end

local function stop_timer()
  if timer then timer:stop(); timer:close(); timer = nil end
end

local function start_timer()
  if timer then return end
  timer = vim.uv.new_timer()
  timer:start(0, 120, vim.schedule_wrap(function()
    frame = frame % #spinner + 1
    vim.cmd.redrawstatus()
  end))
end

local function attention(title, body, level)
  if in_claude_window() then return end
  vim.notify(body, level, { title = title })
  if vim.fn.executable("notify-send") == 1 then
    vim.system({ "notify-send", "-a", "Neovim", "-u", level == vim.log.levels.WARN and "critical" or "normal", title, body })
  end
end

local function on_state(new)
  local previous = current.state
  current = new
  if new.state == "thinking" or new.state == "tool" then start_timer() else stop_timer() end
  if new.state ~= previous then
    if new.state == "waiting" then
      attention("Claude ha bisogno di te", new.detail ~= "" and new.detail or "In attesa di input", vim.log.levels.WARN)
    elseif new.state == "done" and previous ~= "waiting" then
      attention("Claude ha finito", "Risposta pronta", vim.log.levels.INFO)
    end
  end
  vim.schedule(vim.cmd.redrawstatus)
end

local function read_state()
  local f = io.open(state_file, "r")
  if not f then return end
  local text = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, text)
  if ok and type(data) == "table" and data.state then on_state(data) end
end

-- Un'interruzione non fa scattare nessun hook (né Stop né PostToolUse): senza
-- questo lo stato resterebbe "thinking" finché non parte un altro turno.
local function interrupted()
  if current.state == "thinking" or current.state == "tool" then
    on_state({ state = "idle", detail = "", ts = os.time() })
  end
end

function M.watch()
  if watcher then return end
  vim.fn.mkdir(state_dir, "p")
  watcher = vim.uv.new_fs_event()
  watcher:start(state_dir, {}, vim.schedule_wrap(function(err, name)
    if not err and name == vim.fn.fnamemodify(state_file, ":t") then read_state() end
  end))
  vim.on_key(function(key)
    if key == "\3" and vim.fn.mode() == "t" and in_claude_window() then vim.schedule(interrupted) end
  end, vim.api.nvim_create_namespace("ClaudeInterrupt"))
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("ClaudeState", { clear = true }),
    callback = function()
      stop_timer()
      if watcher then watcher:stop() end
      os.remove(state_file)
    end,
  })
end

-- Componente per la statusline (stringa vuota se Claude non è attivo).
function M.status()
  local s = current.state
  if s == "off" or s == nil then return "" end
  if s == "thinking" then return spinner[frame] .. " Claude pensa…" end
  if s == "tool" then return spinner[frame] .. " Claude: " .. (current.detail or "") end
  if s == "waiting" then return "󰂞 Claude ti aspetta" end
  if s == "done" then return "󰄬 Claude: fatto" end
  return "󰧑 Claude"
end

local function terminal()
  return require("claudecode.terminal")
end

local function channel()
  local buf = terminal().get_active_terminal_bufnr()
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  local chan = vim.bo[buf].channel
  if chan == 0 or vim.fn.jobwait({ chan }, 0)[1] ~= -1 then return end
  return chan
end

-- Il testo va scritto sul canale del terminale: basta che la sessione giri.
-- Il collegamento IDE (handshake WebSocket) serve solo per le @mention di file.
local function ready(need_ide)
  if not channel() then
    warn("Nessuna sessione Claude in Neovim: aprila con <leader>ac")
    return false
  end
  if need_ide and not require("claudecode").is_claude_connected() then
    warn("Sessione Claude avviata ma non ancora collegata all'IDE (attendi qualche secondo o prova /ide)")
    return false
  end
  return true
end

local function send(text, focus)
  if not text or vim.trim(text) == "" then return end
  if not ready() then return end
  terminal().send_to_terminal(text, { focus = focus or false })
end

function M.toggle()
  local win = vim.api.nvim_get_current_win()
  terminal().simple_toggle()
  -- Snacks can schedule startinsert when opening a terminal. Restore after it.
  if vim.api.nvim_win_is_valid(win) then vim.api.nvim_set_current_win(win) end
  vim.schedule(function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_set_current_win(win)
      if vim.bo.buftype ~= "terminal" then vim.cmd.stopinsert() end
    end
  end)
end

-- Schermo intero: da qualsiasi finestra apre/focalizza Claude e lo massimizza;
-- se Claude è già a schermo intero, ripristina il layout precedente.
function M.zoom()
  local toggle = require("keymaps").toggle_maximize
  local buf = terminal().get_active_terminal_bufnr()
  if buf and vim.api.nvim_get_current_buf() == buf then
    toggle()
    vim.cmd.startinsert()
    return
  end
  vim.cmd("ClaudeCodeFocus")
  vim.schedule(function()
    local b = terminal().get_active_terminal_bufnr()
    if not b or vim.api.nvim_get_current_buf() ~= b then return end
    if not vim.t.maximize_restore then toggle() end
    vim.cmd.startinsert()
  end)
end

function M.message()
  if not ready() then return end
  vim.ui.input({ prompt = "You: " }, function(text) send(text) end)
end

function M.selection()
  local mode = vim.fn.mode()
  local live = mode == "v" or mode == "V" or mode == "\22"
  local kind = live and mode or vim.fn.visualmode()
  if kind == "\22" then warn("Visual block non supportato: usa v o V"); return end
  local first = vim.fn.getpos(live and "v" or "'<")
  local last = vim.fn.getpos(live and "." or "'>")
  local ok, lines = pcall(vim.fn.getregion, first, last, {
    type = kind,
    exclusive = vim.o.selection == "exclusive",
  })
  if not ok or #lines == 0 then warn("Selezione non disponibile"); return end
  if live then vim.cmd("normal! \27") end
  send(table.concat(lines, "\n"))
end

local function picker(buffers)
  if not ready(true) then return end
  local cwd = require("project").root(0)
  local opts = {
    title = buffers and "Claude: buffers" or "Claude: files (project)",
    confirm = function(p, item)
      local selected = p:selected()
      if #selected == 0 and item then selected = { item } end
      -- Resolve paths before closing changes the active buffer/window.
      local paths, seen, skipped = {}, {}, 0
      for _, entry in ipairs(selected) do
        local path
        if buffers then
          if entry.buf and vim.api.nvim_buf_is_valid(entry.buf) and vim.bo[entry.buf].buftype == "" then
            path = vim.api.nvim_buf_get_name(entry.buf)
          end
        else
          path = Snacks.picker.util.path(vim.tbl_extend("force", { cwd = cwd }, entry))
        end
        if path and path ~= "" then
          path = vim.fn.fnamemodify(path, ":p")
          if not seen[path] then seen[path] = true; paths[#paths + 1] = path end
        else
          skipped = skipped + 1
        end
      end
      p:close()
      vim.schedule(function()
        if skipped > 0 then warn("Saltati buffer speciali o senza nome: " .. skipped) end
        if #paths == 0 or not ready(true) then return end
        for _, path in ipairs(paths) do
          local ok, err = require("claudecode").send_at_mention(path)
          if not ok then warn(err or "Invio del file fallito") end
        end
      end)
    end,
  }
  if buffers then
    Snacks.picker.buffers(opts)
  else
    opts.cwd = cwd
    Snacks.picker.files(opts)
  end
end

function M.files() picker(false) end
function M.buffers() picker(true) end

function M.interrupt()
  if not ready() then return end
  local ok, count = pcall(vim.fn.chansend, channel(), "\27")
  if not ok or count == 0 then warn("Terminale Claude non disponibile") return end
  interrupted()
end

function M.clear() send("/clear") end
function M.model() send("/model", true) end

return M
