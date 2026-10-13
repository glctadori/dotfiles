local M = {}

function M.root(buf)
  local file = vim.api.nvim_buf_get_name(buf or 0)
  local start = file ~= "" and vim.bo[buf or 0].buftype == "" and vim.fs.dirname(file) or vim.fn.getcwd()
  return vim.fs.root(start, { ".git", "pyproject.toml", "platformio.ini", "CMakeLists.txt" }) or start
end

return M
