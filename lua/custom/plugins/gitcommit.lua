local function opencode_build_command(config)
  local shell_quote = function(arg)
    return "'" .. arg:gsub("'", "'\\''") .. "'"
  end

  local args = { 'opencode', 'run' }
  if config.model then
    vim.list_extend(args, { '--model', config.model })
  end
  table.insert(args, (config.system_prompt or '') .. '\n\n' .. (config.prompt or ''))

  local parts = { 'd=$(cat)' }
  for _, a in ipairs(args) do
    table.insert(parts, shell_quote(a))
  end
  table.insert(parts, '"$d"')
  return { 'sh', '-c', table.concat(parts, ' ') }
end

require('gitcommit').setup({
  keymaps = {
    commit = {
      key = '<leader>xc',
      fold_diff = true,
      model = 'opencode/big-pickle',
      extensions = true,
      binary = 'opencode',
      binary_args = {},
      build_command = opencode_build_command
    },
    verbose = {
      key = '<leader>xv',
      fold_diff = true,
      prompt = 'Write the verbose and detailed commit message for the staged diff provided below.',
      desc = 'Generate verbose commit',
      model = 'opencode/big-pickle',
      extensions = true,
      binary = 'opencode',
      binary_args = {},
      build_command = opencode_build_command
    },
  }
})
