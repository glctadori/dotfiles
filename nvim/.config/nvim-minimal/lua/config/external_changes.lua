-- Refresh clean buffers edited by agents; leave unsaved work under user control.
local M = {}

local function safe_to_check()
  return vim.api.nvim_get_mode().mode == "n" and vim.fn.getcmdwintype() == "" and vim.fn.pumvisible() == 0
end

local function file_buffer(buf)
  return vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= ""
end

function M.check_clean()
  if not safe_to_check() then
    return
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local path = vim.api.nvim_buf_get_name(buf)
    if file_buffer(buf) and not vim.bo[buf].modified and vim.fn.filereadable(path) == 1 then
      vim.cmd("checktime " .. buf)
    end
  end
end

function M.diff_disk()
  local source = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(source)
  if not file_buffer(source) or vim.fn.filereadable(path) ~= 1 then
    vim.notify("No readable file on disk for this buffer", vim.log.levels.WARN)
    return
  end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    vim.notify("Cannot read file on disk: " .. path, vim.log.levels.ERROR)
    return
  end
  local filetype = vim.bo[source].filetype
  vim.cmd("diffthis")
  vim.cmd("vertical new")
  local snapshot = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(snapshot, "disk://" .. source .. "/" .. vim.uv.hrtime())
  vim.bo[snapshot].buftype = "nofile"
  vim.bo[snapshot].bufhidden = "wipe"
  vim.bo[snapshot].swapfile = false
  vim.api.nvim_buf_set_lines(snapshot, 0, -1, false, lines)
  vim.bo[snapshot].filetype = filetype
  vim.bo[snapshot].modified = false
  vim.bo[snapshot].modifiable = false
  vim.cmd("diffthis")
  vim.keymap.set("n", "q", function()
    vim.cmd("diffoff!")
    vim.cmd("close")
  end, { buffer = snapshot, desc = "Close disk comparison" })
end

function M.setup()
  local group = vim.api.nvim_create_augroup("minimal_external_changes", { clear = true })
  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "TermClose", "TermLeave" }, {
    group = group,
    callback = function()
      if safe_to_check() and file_buffer(vim.api.nvim_get_current_buf()) then
        -- Preserve Neovim's native conflict and deletion prompts for dirty buffers.
        vim.cmd("checktime")
      end
    end,
  })
  vim.api.nvim_create_autocmd("FileChangedShellPost", {
    group = group,
    callback = function(event)
      if not vim.bo[event.buf].modified then
        vim.notify("External file change: " .. vim.fn.fnamemodify(event.file, ":~:."))
      end
    end,
  })
  local timer = assert(vim.uv.new_timer())
  timer:start(1000, 1000, vim.schedule_wrap(M.check_clean))
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    once = true,
    callback = function()
      timer:stop()
      timer:close()
    end,
  })
  vim.api.nvim_create_user_command("DiffDisk", M.diff_disk, { desc = "Compare buffer with a disk snapshot" })
  vim.api.nvim_create_user_command("CheckFiles", function()
    vim.cmd("checktime")
  end, { desc = "Check external changes, including unsaved buffers" })
  vim.keymap.set("n", "<leader>gd", M.diff_disk, { desc = "Compare buffer with disk" })
end

return M
