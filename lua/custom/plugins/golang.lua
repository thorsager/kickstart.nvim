-- dropped: nvim-lspconfig dependency (optional, expected to be loaded elsewhere)
-- dropped: lazy loading via event=CmdlineEnter and ft=go/gomod (vim.pack has no lazy loading)
-- dropped: build step `require("go.install").update_all_sync()` -- run manually via :lua require("go.install").update_all_sync()
vim.pack.add {
  'https://github.com/ray-x/guihua.lua',
  'https://github.com/ray-x/go.nvim',
}

require('go').setup()

local format_sync_grp = vim.api.nvim_create_augroup('GoFormat', {})
vim.api.nvim_create_autocmd('BufWritePre', {
  pattern = '*.go',
  callback = function()
    require('go.format').goimports()
  end,
  group = format_sync_grp,
})
