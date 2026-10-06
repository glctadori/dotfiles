local M = {}

local term = {
  buf = nil,
  win = nil,
}

function M.toggle()
  if term.win and vim.api.nvim_win_is_valid(term.win) then
    vim.api.nvim_win_close(term.win, true)
    term.win = nil
    return
  end

  vim.cmd("botright 12split")
  term.win = vim.api.nvim_get_current_win()

  if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
    vim.api.nvim_win_set_buf(term.win, term.buf)
  else
    vim.cmd("terminal")
    term.buf = vim.api.nvim_get_current_buf()
  end

  vim.cmd("startinsert")
end

return M
