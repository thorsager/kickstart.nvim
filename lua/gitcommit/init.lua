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
      if opts.keymaps then
        for _, entry in ipairs(opts.keymaps) do
          vim.keymap.set('n', entry.key, function()
            M.generate(ev.buf, entry)
          end, { buffer = ev.buf, desc = entry.desc or 'Generate commit message' })
        end
      end
    end,
  })
end

function M.generate(bufnr, entry_opts)
  local cfg = entry_opts or opts
  local diff = vim.fn.systemlist(table.concat(cfg.diff_command, ' '))
  if vim.v.shell_error ~= 0 and #diff == 0 then
    vim.notify('Failed to get git diff', vim.log.levels.ERROR)
    return
  end
  if #diff == 0 then
    diff = { '(no staged changes)' }
  end

  if cfg.preview then
    local state = ui.open(bufnr, diff, cfg)
    command.run(diff, cfg, state)
  else
    command.run_direct(diff, cfg, vim.api.nvim_get_current_win(), bufnr)
  end
end

return M
