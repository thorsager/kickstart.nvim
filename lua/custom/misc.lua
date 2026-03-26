vim.api.nvim_set_option_value('colorcolumn', '79,120', {})

-- to force color after schema
-- vim.api.nvim_create_autocmd('ColorScheme', {
--   pattern = '*',
--   callback = function() vim.api.nvim_set_hl(0, 'ColorColumn', { bg = '#ff5555' }) end,
-- })
