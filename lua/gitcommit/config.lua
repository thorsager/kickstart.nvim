local M = {}

-- Presets for supported AI CLI engines. `engine` selects the preset that
-- provides `binary` and `binary_args`; setting those directly still wins.
M.engines = {
  pi = {
    binary = 'pi',
    binary_args = {
      '--no-session',
      '--no-tools',
      '--no-context-files',
      '--no-skills',
      '--no-prompt-templates',
    },
  },
  omp = {
    binary = 'omp',
    binary_args = {
      '--no-session',
      '--no-tools',
      '--no-lsp',
      '--no-rules',
      '--no-skills',
    },
  },
}

M.defaults = {
  engine = 'pi',
  keymap = '<leader>xc',
  show_diff = true,
  preview = true,
  width_ratio = 0.85,
  height_ratio = 0.80,
  border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
  model = nil,
  extensions = false,
  system_prompt = 'You are an expert software engineer and version control '
    .. 'master. Your task is to write a git commit message based on the '
    .. 'provided `git diff`. '
    .. 'Given a staged git diff, output a commit message following the '
    .. 'commitizen convention (e.g. "feat:", "fix:", "refactor:"). '
    .. 'The subject line must be under 50 characters. '
    .. 'If a body is needed, wrap each line at 72 characters. '
    .. 'You must respond with ONLY the raw commit message — '
    .. 'no preface, no explanation, no commentary, '
    .. 'no markdown formatting, no code fences, no backticks.',
  prompt = 'Write the commit message for the staged diff provided below.',
  build_command = nil,
  diff_command = { 'git', 'diff', '--cached' },
  fold_diff = true,
  keymaps = nil,
}

-- Fill in `binary` and `binary_args` from the engine preset when unset.
-- Mutates and returns `opts`.
function M.resolve(opts)
  local preset = M.engines[opts.engine]
  if not preset then
    local fallback = M.defaults.engine
    vim.notify(
      'gitcommit: unknown engine ' .. vim.inspect(opts.engine)
        .. ", falling back to '" .. fallback .. "'",
      vim.log.levels.WARN
    )
    opts.engine = fallback
    preset = M.engines[fallback]
  end
  if opts.binary == nil then opts.binary = preset.binary end
  if opts.binary_args == nil then opts.binary_args = vim.deepcopy(preset.binary_args) end
  return opts
end

function M.merge(user_opts)
  user_opts = user_opts or {}
  local keymaps = user_opts.keymaps
  if not keymaps and user_opts.keymap then keymaps = { default = { key = user_opts.keymap } } end
  local base = vim.tbl_deep_extend('force', M.defaults, user_opts)
  -- Template of unresolved top-level opts used as the base for keymap
  -- entries, so a per-entry `engine` can still select a different preset.
  local template = vim.deepcopy(base)
  template.keymaps = nil
  local resolved = M.resolve(base)
  if keymaps then
    resolved.keymaps = {}
    for id, entry in pairs(keymaps) do
      resolved.keymaps[id] = M.resolve(vim.tbl_deep_extend('force', template, entry))
    end
  end
  return resolved
end

return M
