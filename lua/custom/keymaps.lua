vim.api.nvim_create_autocmd('FileType', {
  pattern = 'go',
  callback = function(_)
    vim.keymap.set('n', '<leader>g', '', { desc = '[G]o' })
    vim.keymap.set('n', '<leader>gt', '', { desc = '[G]o [T]esting' })
    vim.keymap.set('n', '<leader>gtf', '<cmd>:GoTestFunc<CR>', { desc = 'Run [G]o [T]est [F]unction' })
    vim.keymap.set('n', '<leader>gtl', '<cmd>:GoTestFile<CR>', { desc = 'Run [G]o [T]est fi[L]e' })
    vim.keymap.set('n', '<leader>gi', '<cmd>:GoImports<CR>', { desc = 'Run [G]o [i]mports' })
  end,
})
vim.keymap.set('n', '<leader>z', '<cmd>:ZenMode<CR>', { desc = 'Toggle [Z]enMode' })
vim.keymap.set('n', '<leader>rw', '<cmd>:Ex<CR>', { desc = 'Open Net[RW]' })
vim.keymap.set('n', '<leader>cpc', '<cmd>:CopilotChat<CR>', { desc = '[C]o[P]ilot[C]hat' })
vim.keymap.set('n', '<leader>cpm', '<cmd>:CopilotChatCommit<CR>', { desc = '[C]o[P]ilotChat co[M]mit' })
vim.keymap.set('n', '<leader>ng', '<cmd>:Neogit<CR>', { desc = '[N]eo[G]it' })
vim.keymap.set('n', '<leader>cfr', '<cmd>let @*=expand("%")<CR>', { desc = '[C]opy [F]ile [R]elative path' })
vim.keymap.set('n', '<leader>cfp', '<cmd>let @*=expand("%:p")<CR>', { desc = '[C]opy [F]ile absolute [P]ath' })
vim.keymap.set('n', '<leader>cfn', '<cmd>let @*=expand("%:t")<CR>', { desc = '[C]opy [F]ile [N]ame' })
vim.keymap.set('n', '<leader>cfg', '<cmd>.GBrowse!<CR>', { desc = '[C]opy [F]ile:line [G]itHub URL' })

-- vim.keymap.set('n', '<leader>grn', '<cmd>:GoRun<CR>', { desc = '[G]o [R]u[N]' })
-- vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open parent directory' })

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'java',
  callback = function(_) vim.keymap.set('n', '<leader>mt', '<cmd>:MavenTest<CR>', { desc = 'Run [M]aven [T]est function/class' }) end,
})
vim.keymap.set('n', '<leader>mc', '<cmd>:MavenClean<CR>', { desc = 'Run [M]aven [C]lean' })
vim.keymap.set('n', '<leader>mva', '<cmd>:MavenVerifyAll<CR>', { desc = 'Run [M]aven [V]erify all' })
vim.keymap.set('n', '<leader>mta', '<cmd>:MavenTestAll<CR>', { desc = 'Run [M]aven [T]test all' })

-- Exit terminal mode and switch windows in one motion
local esc = vim.api.nvim_replace_termcodes('<C-\\><C-n>', true, true, true)
vim.keymap.set('t', '<C-h>', function()
  vim.api.nvim_feedkeys(esc, 'n', false)
  vim.schedule(function() require('nvim-tmux-navigation').NvimTmuxNavigateLeft() end)
end, { noremap = true, desc = 'Move left from terminal' })
vim.keymap.set('t', '<C-j>', function()
  vim.api.nvim_feedkeys(esc, 'n', false)
  vim.schedule(function() require('nvim-tmux-navigation').NvimTmuxNavigateDown() end)
end, { noremap = true, desc = 'Move down from terminal' })
vim.keymap.set('t', '<C-k>', function()
  vim.api.nvim_feedkeys(esc, 'n', false)
  vim.schedule(function() require('nvim-tmux-navigation').NvimTmuxNavigateUp() end)
end, { noremap = true, desc = 'Move up from terminal' })
vim.keymap.set('t', '<C-l>', function()
  vim.api.nvim_feedkeys(esc, 'n', false)
  vim.schedule(function() require('nvim-tmux-navigation').NvimTmuxNavigateRight() end)
end, { noremap = true, desc = 'Move right from terminal' })

-- allow <C-[hjkl]> navigation through tmux panes when in netwr
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'netrw',
  callback = function(ev)
    local nvim_tmux_nav = require 'nvim-tmux-navigation'
    local opts = { buffer = ev.buf }
    vim.keymap.set('n', '<C-h>', nvim_tmux_nav.NvimTmuxNavigateLeft, opts)
    vim.keymap.set('n', '<C-j>', nvim_tmux_nav.NvimTmuxNavigateDown, opts)
    vim.keymap.set('n', '<C-k>', nvim_tmux_nav.NvimTmuxNavigateUp, opts)
    vim.keymap.set('n', '<C-l>', nvim_tmux_nav.NvimTmuxNavigateRight, opts)
    vim.keymap.set('n', '<C-\\>', nvim_tmux_nav.NvimTmuxNavigateLastActive, opts)
    vim.keymap.set('n', '<C-Space>', nvim_tmux_nav.NvimTmuxNavigateNext, opts)
  end,
})
