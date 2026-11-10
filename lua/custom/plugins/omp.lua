-- Disable the default <leader>oa maps and bind your own (flag before add)
-- vim.g.omp_nvim_no_keymaps = true
-- vim.keymap.set("n", "<leader>om", "<Cmd>OmpAsk<CR>", { desc = "omp: ask" })
-- vim.keymap.set("x", "<leader>om", function()
--   require("omp_nvim").ask()
-- end, { desc = "omp: ask selection" })

vim.pack.add({
  {
    src = "https://github.com/l3aro/omp.nvim",
    version = vim.version.range("*"), -- Latest stable release
  },
})
