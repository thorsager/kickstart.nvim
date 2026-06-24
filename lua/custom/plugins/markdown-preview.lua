vim.pack.add {
  { src = 'https://github.com/selimacerbas/live-server.nvim' },
  { src = 'https://github.com/selimacerbas/markdown-preview.nvim', version = 'v1.9.0' }
}

require("markdown_preview").setup({
  -- all optional; sane defaults shown
  instance_mode = "takeover",  -- "takeover" (one tab) or "multi" (tab per instance)
  port = 0,                    -- 0 = auto (8421 for takeover, OS-assigned for multi)
  open_browser = true,
  default_theme = "dark",      -- "dark" or "light"; initial preview theme
  debounce_ms = 300,
})

vim.keymap.set("n", "<leader>mps", "<cmd>MarkdownPreview<cr>", { desc = "Markdown: Start preview" })
vim.keymap.set("n", "<leader>mpS", "<cmd>MarkdownPreviewStop<cr>", { desc = "Markdown: Stop preview" })
vim.keymap.set("n", "<leader>mpr", "<cmd>MarkdownPreviewRefresh<cr>", { desc = "Markdown: Refresh preview" })
