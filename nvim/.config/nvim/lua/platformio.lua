local M = {}

local boards = {
  { id = "uno", name = "Arduino Uno" },
  { id = "esp32dev", name = "ESP32 Dev Module" },
}

local term = { buf = nil, win = nil, job = nil }

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "PlatformIO" })
end

local function project_root()
  local file = vim.api.nvim_buf_get_name(0)
  local start = file ~= "" and vim.bo.buftype == "" and vim.fs.dirname(file) or vim.fn.getcwd()
  return vim.fs.root(start, { "platformio.ini" })
end

-- Un solo terminale per i comandi pio: il nuovo comando chiude il precedente,
-- così l'upload non trova la seriale occupata dal monitor.
local function run(args, cwd, on_success)
  if vim.fn.executable("pio") ~= 1 then
    return notify("Comando mancante: pio", vim.log.levels.ERROR)
  end
  pcall(vim.cmd, "silent! wall")

  if term.job then pcall(vim.fn.jobstop, term.job) end
  if term.win and vim.api.nvim_win_is_valid(term.win) then
    vim.api.nvim_set_current_win(term.win)
  else
    vim.cmd("botright 14split")
    term.win = vim.api.nvim_get_current_win()
  end

  local old = term.buf
  term.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(term.win, term.buf)
  if old and vim.api.nvim_buf_is_valid(old) then
    vim.api.nvim_buf_delete(old, { force = true })
  end

  term.job = vim.fn.jobstart(vim.list_extend({ "pio" }, args), {
    cwd = cwd,
    term = true,
    on_exit = function(_, code)
      term.job = nil
      if code == 0 and on_success then vim.schedule(on_success) end
    end,
  })
  vim.cmd("startinsert")
end

-- compile_commands.json per clangd: senza, non trova Arduino.h e segna tutto
-- come errore. Si rigenera in background quando manca o è più vecchio di
-- platformio.ini, poi clangd viene riavviato per rileggerlo.
local generating = {}

local function compiledb(root, force)
  if generating[root] or vim.fn.executable("pio") ~= 1 then return end
  local db = root .. "/compile_commands.json"
  local ini = vim.uv.fs_stat(root .. "/platformio.ini")
  local stat = vim.uv.fs_stat(db)
  if not force and stat and ini and stat.mtime.sec >= ini.mtime.sec then return end

  generating[root] = true
  notify("Genero compile_commands.json…")
  vim.system({ "pio", "run", "--target", "compiledb", "--silent" }, { cwd = root, text = true },
    function(result)
      vim.schedule(function()
        generating[root] = nil
        if result.code ~= 0 then
          local err = vim.trim((result.stderr or "") .. "\n" .. (result.stdout or ""))
          return notify("compiledb fallito:\n" .. err, vim.log.levels.ERROR)
        end
        for _, client in ipairs(vim.lsp.get_clients({ name = "clangd" })) do
          local bufs = vim.tbl_keys(client.attached_buffers)
          client:stop()
          vim.defer_fn(function()
            for _, buf in ipairs(bufs) do
              if vim.api.nvim_buf_is_valid(buf) then
                vim.api.nvim_exec_autocmds("FileType", { buffer = buf })
              end
            end
          end, 500)
        end
        notify("compile_commands.json aggiornato")
      end)
    end)
end

local function in_project(args)
  local root = project_root()
  if not root then
    return notify("Nessun platformio.ini: lancia prima :PioInit", vim.log.levels.ERROR)
  end
  run(args, root)
end

local function choose_board(cwd)
  vim.ui.select(boards, {
    prompt = "Board (" .. vim.fn.fnamemodify(cwd, ":~") .. ")",
    format_item = function(board) return board.name .. "  [" .. board.id .. "]" end,
  }, function(board)
    if board then
      run({ "project", "init", "--board", board.id }, cwd, function() compiledb(cwd, true) end)
    end
  end)
end

-- Senza platformio.ini il progetto nasce nella cwd: se non è vuota, chiedi prima.
function M.init()
  local root = project_root()
  local cwd = root or vim.fn.getcwd()
  if root or #vim.fn.readdir(cwd) == 0 then return choose_board(cwd) end
  vim.ui.select({ "No", "Sì" }, {
    prompt = "Creare un progetto PlatformIO in " .. vim.fn.fnamemodify(cwd, ":~") .. " (non vuota)?",
  }, function(answer)
    if answer == "Sì" then choose_board(cwd) end
  end)
end

function M.build() in_project({ "run" }) end
function M.upload() in_project({ "run", "--target", "upload" }) end
function M.monitor() in_project({ "device", "monitor" }) end

function M.setup()
  local group = vim.api.nvim_create_augroup("PlatformIO", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "c", "cpp", "arduino" },
    callback = function()
      local root = project_root()
      if root then compiledb(root, false) end
    end,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "platformio.ini",
    callback = function(event) compiledb(vim.fs.dirname(event.match), true) end,
  })

  local commands = {
    { "PioInit", M.init, "Init progetto (scegli board)", "<leader>pi" },
    { "PioBuild", M.build, "Compila", "<leader>pb" },
    { "PioUpload", M.upload, "Flash sulla board", "<leader>pu" },
    { "PioMonitor", M.monitor, "Monitor seriale", "<leader>pm" },
  }
  for _, c in ipairs(commands) do
    vim.api.nvim_create_user_command(c[1], c[2], { desc = "PlatformIO: " .. c[3] })
    vim.keymap.set("n", c[4], c[2], { silent = true, desc = "PlatformIO: " .. c[3] })
  end
end

return M
