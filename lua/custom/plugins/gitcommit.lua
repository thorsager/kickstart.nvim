require('gitcommit').setup({
  keymaps = {
    commit = {
      key = '<leader>xc',
      desc = 'Generate commit message',
      model = 'openrouter/free',
      prompt = 'Write the short and concise commit message, for the staged diff provided below.',
    },
    verbose = {
      key = '<leader>xv',
      desc = 'Generate verbose commit message',
      model = 'openrouter/free',
      prompt = 'Write the verbose and detailed commit message, for the staged diff provided below.',
    },
  }
})
