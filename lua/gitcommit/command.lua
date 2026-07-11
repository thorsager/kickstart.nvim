local M = {}

function M.build(config)
  if config.build_command then
    return config.build_command(config)
  end
  local cmd = { config.binary }
  vim.list_extend(cmd, config.binary_args)
  if not config.extensions then
    table.insert(cmd, '--no-extensions')
  end
  if config.model then
    vim.list_extend(cmd, { '--model', config.model })
  end
  vim.list_extend(cmd, { '--system-prompt', config.system_prompt, '-p', config.prompt })
  return cmd
end

function M.clean_output(lines)
  local cleaned = {}
  local started = false
  for _, line in ipairs(lines) do
    if line:match '^```gitcommit' then
      started = true
    elseif line:match '^```$' and started then
      started = false
    elseif started then
      table.insert(cleaned, line)
    end
  end
  if #cleaned == 0 then cleaned = lines end
  while #cleaned > 0 and cleaned[1] == '' do table.remove(cleaned, 1) end
  while #cleaned > 0 and cleaned[#cleaned] == '' do table.remove(cleaned, #cleaned) end
  return cleaned
end

local function truncate_arg(arg, max_len)
  if not arg or #arg <= max_len then return arg end
  return arg:sub(1, max_len) .. '...'
end

local function truncate_prompt(arg)
  if not arg or #arg <= 13 then return arg end
  return arg:sub(1, 5) .. '...' .. arg:sub(-5)
end

local function shell_quote(arg)
  if arg:match('^[%w%-%._/]+$') then return arg end
  return "'" .. arg:gsub("'", "'\\''") .. "'"
end

local function display_cmd(cmd)
  local parts = {}
  local skip_next = false
  for i, arg in ipairs(cmd) do
    if skip_next then
      skip_next = false
    elseif arg == '--system-prompt' or arg == '-p' then
      table.insert(parts, arg)
      table.insert(parts, shell_quote(truncate_prompt(cmd[i + 1] or '')))
      skip_next = true
    else
      table.insert(parts, shell_quote(truncate_arg(arg, 80)))
    end
  end
  return table.concat(parts, ' ')
end

function M.run(diff, config, state)
  local cmd = M.build(config)
  local stderr_data = ''
  return vim.system(cmd, {
    stdin = table.concat(diff, '\n'),
    stdout = function(err, data)
      if not data then return end
      vim.schedule(function()
        state:append_output(data)
      end)
    end,
    stderr = function(err, data)
      if not data then return end
      stderr_data = stderr_data .. data
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(state.out_buf) then
          vim.notify(config.binary .. ' stderr: ' .. data, vim.log.levels.WARN)
        end
      end)
    end,
  }, function(obj)
    vim.schedule(function()
      if state.closed then return end
      if obj.code ~= 0 then
        local full_cmd = display_cmd(cmd)
        local msg = config.binary .. ' exited with code ' .. obj.code
          .. '\n\ncommand:\n' .. full_cmd
        if stderr_data ~= '' then
          msg = msg .. '\n\nstderr:\n' .. stderr_data
        end
        state:show_error(msg)
        vim.notify(config.binary .. ' exited with code ' .. obj.code, vim.log.levels.ERROR)
        return
      end
      state:stop_spinner()
      if not vim.api.nvim_buf_is_valid(state.out_buf) then return end
      local lines = vim.api.nvim_buf_get_lines(state.out_buf, 0, -1, false)
      local cleaned = M.clean_output(lines)
      state:finalize_output(cleaned)
    end)
  end)
end

function M.run_direct(diff, config, orig_win, orig_buf)
  local cmd = M.build(config)
  local collected = {}
  local stderr_data = ''
  local spinner_idx = 1
  local spinner_frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
  local spinner_msg_id = nil
  local spinner_timer = vim.uv.new_timer()
  spinner_timer:start(0, 80, function()
    vim.schedule(function()
      local frame = spinner_frames[spinner_idx]
      spinner_idx = spinner_idx % #spinner_frames + 1
      spinner_msg_id = vim.notify(frame .. ' Generating commit message...', vim.log.levels.INFO, { replace = spinner_msg_id })
    end)
  end)

  return vim.system(cmd, {
    stdin = table.concat(diff, '\n'),
    stdout = function(err, data)
      if not data then return end
      vim.schedule(function()
        local append = vim.split(data, '\n')
        if append[#append] == '' then table.remove(append) end
        vim.list_extend(collected, append)
      end)
    end,
    stderr = function(err, data)
      if not data then return end
      stderr_data = stderr_data .. data
      vim.schedule(function()
        vim.notify(config.binary .. ' stderr: ' .. data, vim.log.levels.WARN)
      end)
    end,
  }, function(obj)
    vim.schedule(function()
      spinner_timer:stop()
      spinner_timer:close()
      vim.notify('', nil, { replace = spinner_msg_id })
      if obj.code ~= 0 then
        local full_cmd = display_cmd(cmd)
        local msg = config.binary .. ' exited with code ' .. obj.code
          .. '\n\ncommand:\n' .. full_cmd
        if stderr_data ~= '' then
          msg = msg .. '\n\nstderr:\n' .. stderr_data
        end
        vim.notify(msg, vim.log.levels.ERROR)
        return
      end
      local cleaned = M.clean_output(collected)
      if #cleaned == 0 then return end
      if vim.api.nvim_win_is_valid(orig_win) and vim.api.nvim_buf_is_valid(orig_buf) then
        vim.api.nvim_set_current_win(orig_win)
        local cursor = vim.api.nvim_win_get_cursor(orig_win)
        vim.api.nvim_buf_set_lines(orig_buf, cursor[1] - 1, cursor[1] - 1, false, cleaned)
      end
    end)
  end)
end

return M
