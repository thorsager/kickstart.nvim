local config = require('gitcommit.config')
local ui = require('gitcommit.ui')
local command = require('gitcommit.command')

local M = {}
local opts = {}

local function setup_highlights()
  local groups = {
    GitcommitBorder = { link = 'FloatBorder', default = true },
    GitcommitTitle = { link = 'Title', default = true },
    GitcommitNormal = { link = 'NormalFloat', default = true },
    GitcommitCursorLine = { link = 'CursorLine', default = true },
  }
  for name, val in pairs(groups) do
    vim.api.nvim_set_hl(0, name, val)
  end
end

function M.setup(user_opts)
  opts = config.merge(user_opts)
  setup_highlights()
  vim.api.nvim_create_autocmd('ColorScheme', {
    callback = setup_highlights,
  })
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'gitcommit',
    callback = function(ev)
      vim.keymap.set('n', opts.keymap, function()
        M.generate(ev.buf)
      end, { buffer = ev.buf, desc = 'Generate commit message' })
    end,
  })
end

function M.generate(bufnr)
  local diff = vim.fn.systemlist(table.concat(opts.diff_command, ' '))
  if vim.v.shell_error ~= 0 and #diff == 0 then
    vim.notify('Failed to get git diff', vim.log.levels.ERROR)
    return
  end
  if #diff == 0 then
    diff = { '(no staged changes)' }
  end

  if opts.preview then
    local state = ui.open(bufnr, diff, opts)
    command.run(diff, opts, state)
  else
    command.run_direct(diff, opts, vim.api.nvim_get_current_win(), bufnr)
  end
end

return M
