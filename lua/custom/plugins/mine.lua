local spell_checked_types = { 'text', 'plaintext', 'markdown' }

-- misc
vim.api.nvim_set_option_value('colorcolumn', '79,120', {})
vim.api.nvim_set_option_value('relativenumber', true, {})
vim.opt.list = true
vim.opt.listchars:append {
  eol = '↲',
  tab = '»·',
  trail = '░',
  extends = '<',
  precedes = '>',
  conceal = '┊',
  nbsp = '☠',
}

-- open *.Containerfile, just like .Dockerfile
vim.filetype.add {
  extension = {
    Containerfile = 'dockerfile',
  },
}

-- keymaps
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'go',
  callback = function(_)
    vim.keymap.set('n', '<leader>g', '', { desc = '[G]o' })
    vim.keymap.set('n', '<leader>gt', '', { desc = '[G]o [T]esting' })
    vim.keymap.set('n', '<leader>gtf', '<cmd>:GoTestFunc<CR>', { desc = 'Run [G]o [T]est [F]unction' })
    vim.keymap.set('n', '<leader>gtl', '<cmd>:GoTestFile<CR>', { desc = 'Run [G]o [T]est fi[L]e' })
    vim.keymap.set('n', '<leader>gi', '<cmd>:GoImports<CR>', { desc = 'Run [G]o [i]mports' })
    vim.keymap.set('n', '<leader>dg', '', { desc = 'Debug [G]o' })
    vim.keymap.set('n', '<leader>dgt', function()
      require('dap-go').debug_test()
    end, { desc = '[D]ebug [G]o [T]est' })
    vim.keymap.set('n', '<leader>dgl', function()
      require('dap-go').debug_last_test()
    end, { desc = '[D]ebug [G]o [L]ast test' })
  end,
})

vim.keymap.set('n', '<leader>z', '<cmd>:ZenMode<CR>', { desc = 'Toggle [Z]enMode' })
vim.keymap.set('n', '<leader>rw', '<cmd>:Ex<CR>', { desc = 'Open Net[RW]' })
vim.keymap.set('n', '<leader>ng', '<cmd>:Neogit<CR>', { desc = '[N]eo[G]it' })

vim.keymap.set('n', '<leader>cpc', '<cmd>:CopilotChat<CR>', { desc = '[C]o[P]ilot[C]hat' })
vim.keymap.set('n', '<leader>cpm', '<cmd>:CopilotChatCommit<CR>', { desc = '[C]o[P]ilotChat co[M]mit' })
vim.keymap.set('n', '<leader>cfr', '<cmd>let @*=expand("%")<CR>', { desc = '[C]opy [F]ile [R]elative path' })
vim.keymap.set('n', '<leader>cfp', '<cmd>let @*=expand("%:p")<CR>', { desc = '[C]opy [F]ile absolute [P]ath' })
vim.keymap.set('n', '<leader>cfn', '<cmd>let @*=expand("%:t")<CR>', { desc = '[C]opy [F]ile [N]ame' })
vim.keymap.set('n', '<leader>cfvi .gvi .', '<cmd>.GBrowse!<CR>', { desc = '[C]opy [F]ile:line [G]itHub URL' })

-- Exit terminal mode and switch windows in one motion
local esc = vim.api.nvim_replace_termcodes('<C-\\><C-n>', true, true, true)
vim.keymap.set('t', '<C-h>', function()
  vim.api.nvim_feedkeys(esc, 'n', false)
  vim.schedule(function()
    require('nvim-tmux-navigation').NvimTmuxNavigateLeft()
  end)
end, { noremap = true, desc = 'Move left from terminal' })
vim.keymap.set('t', '<C-j>', function()
  vim.api.nvim_feedkeys(esc, 'n', false)
  vim.schedule(function()
    require('nvim-tmux-navigation').NvimTmuxNavigateDown()
  end)
end, { noremap = true, desc = 'Move down from terminal' })
vim.keymap.set('t', '<C-k>', function()
  vim.api.nvim_feedkeys(esc, 'n', false)
  vim.schedule(function()
    require('nvim-tmux-navigation').NvimTmuxNavigateUp()
  end)
end, { noremap = true, desc = 'Move up from terminal' })
vim.keymap.set('t', '<C-l>', function()
  vim.api.nvim_feedkeys(esc, 'n', false)
  vim.schedule(function()
    require('nvim-tmux-navigation').NvimTmuxNavigateRight()
  end)
end, { noremap = true, desc = 'Move right from terminal' })

vim.keymap.set('n', '<leader>d', '', { desc = '[D]ebug' })
vim.keymap.set('n', '<leader>dv', function()
  require('dapui').toggle()
end, { desc = '[D]ebug Toggle [V]iew' })
vim.keymap.set('n', '<leader>dc', function()
  require('dap').continue()
end, { desc = '[D]ebug [C]ontinue/Start' })
vim.keymap.set('n', '<leader>di', function()
  require('dap').step_into()
end, { desc = '[D]ebug Step [I]nto' })
vim.keymap.set('n', '<leader>do', function()
  require('dap').step_over()
end, { desc = '[D]ebug Step [O]ver' })
vim.keymap.set('n', '<leader>du', function()
  require('dap').step_out()
end, { desc = '[D]ebug Step o[U]t' })
vim.keymap.set('n', '<leader>dt', function()
  require('dap').close()
end, { desc = '[D]ebug [T]erminate/Close' })

-- allow <C-[hjkl]> navigation through tmux panes when in netrw
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
    vim.opt_local.list = false
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = spell_checked_types,
  callback = function(_)
    vim.api.nvim_set_option_value('spelllang', 'en_us', {})
    vim.api.nvim_set_option_value('spell', true, {})
    vim.keymap.set('n', '<leader>p', '', { desc = 'S[p]ell' })
    vim.keymap.set('n', '<leader>pd', function()
      vim.api.nvim_set_option_value('spelllang', 'da', {})
    end, { desc = 'S[p]ell Danish' })
    vim.keymap.set('n', '<leader>pe', function()
      vim.api.nvim_set_option_value('spelllang', 'en', {})
    end, { desc = 'S[p]ell English' })
    vim.keymap.set('n', '<leader>pb', function()
      vim.api.nvim_set_option_value('spelllang', 'en,da', {})
    end, { desc = 'S[p]ell English & Danish' })
  end,
})