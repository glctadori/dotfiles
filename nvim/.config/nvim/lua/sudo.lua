local M = {}

function M.write()
  local file = vim.fn.expand("%:p")

  if file == "" then
    vim.notify("Buffer senza file", vim.log.levels.ERROR)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local content = table.concat(lines, "\n") .. "\n"

  local output = vim.fn.system(
    { "sudo", "-A", "tee", file },
    content
  )

  if vim.v.shell_error ~= 0 then
    vim.notify(
      "Sudo write fallito:\n" .. output,
      vim.log.levels.ERROR
    )
    return
  end

  vim.bo.modified = false
  vim.notify("Scritto come root: " .. file)
end

vim.api.nvim_create_user_command("W", M.write, {
  desc = "Write file with sudo",
})

return M
