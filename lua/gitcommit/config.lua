local M = {}

M.defaults = {
  keymap = '<leader>xc',
  show_diff = true,
  preview = true,
  width_ratio = 0.85,
  height_ratio = 0.80,
  border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
  binary = 'pi',
  model = nil,
  binary_args = {
    '--no-session',
    '--no-tools',
    '--no-context-files',
    '--no-skills',
    '--no-prompt-templates',
    '--no-extensions',
  },
  system_prompt = 'You are a commit message generator. '
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

function M.merge(user_opts)
  user_opts = user_opts or {}
  local keymaps = user_opts.keymaps
  if not keymaps and user_opts.keymap then keymaps = { { key = user_opts.keymap } } end
  local merged = vim.tbl_deep_extend('force', M.defaults, user_opts)
  if keymaps then
    merged.keymaps = {}
    for _, entry in ipairs(keymaps) do
      table.insert(merged.keymaps, vim.tbl_deep_extend('force', merged, entry))
    end
  end
  return merged
end

return M
