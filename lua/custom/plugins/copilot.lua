return {
  {
    'CopilotC-Nvim/CopilotChat.nvim',
    dependencies = {
      { 'zbirenbaum/copilot.lua' },
      'zbirenbaum/copilot.lua',
      { 'nvim-lua/plenary.nvim', branch = 'master' }, -- for curl, log and async functions
    },
    build = 'make tiktoken', -- Only on MacOS or Linux
    opts = {
      -- See Configuration section for options
    },
    -- See Commands section for default commands if you want to lazy load on them
  },
}
-- return {
--   'zbirenbaum/copilot.lua',
--   event = 'InsertEnter', -- or remove event to load manually
--   config = function()
--     require('copilot').setup {}
--   end,
--   enabled = true, -- disables at startup
-- }
--
