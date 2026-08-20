require('gitcommit').setup({
  keymaps = {
    -- {key = '<leader>xc', fold_diff = true, 
    -- model='corti/corti-s1-mini-instant'
    -- },
    {
      key = '<leader>xc',
      fold_diff = true,
      model='corti/corti-s1-mini-instant',
      extensions = true
    },
    {
      key = '<leader>xv',
      fold_diff = true,
      prompt = 'Write the verbose and detailed commit message for the staged diff provided below.',
      desc='Generate verbose commit message',
      model='corti/corti-s1-mini-instant',
      extensions = true
    },
  }
})
