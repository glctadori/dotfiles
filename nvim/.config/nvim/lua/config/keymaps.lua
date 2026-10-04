vim.keymap.set("n", "<leader>rr", function()
  dofile(vim.env.MYVIMRC)
end, { desc = "Reload config" })

vim.keymap.set("n", "S", ":%s//g<Left><Left>", {
  desc = "Replace all",
})

vim.keymap.set("v", "S", ":s//g<Left><Left>", {
  desc = "Replace selection",
})
