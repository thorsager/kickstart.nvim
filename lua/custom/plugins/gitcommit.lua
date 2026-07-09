require('gitcommit').setup({
  keymaps = {
    {key = '<leader>xc', fold_diff = true},
    {
      key = '<leader>xv',
      fold_diff = true,
      prompt = 'Write the verbose and detailed commit message for the staged diff provided below.',
      desc='Generate versose commit'
    },
  }
})
