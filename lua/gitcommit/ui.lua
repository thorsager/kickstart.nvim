local M = {}

local spinner_frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

function M.diff_foldexpr(lnum)
  local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1] or ''
  if line:match '^diff %-%-git' or line:match '^index ' or line:match '^%-%-%-' or line:match '^%+%+%+' then
    return '>1'
  end
  if line:match '^@@' then
    return '>1'
  end
  return '1'
end

function M.open(orig_buf, diff, opts)
  local orig_win = vim.api.nvim_get_current_win()

  local state = {
    orig_buf = orig_buf,
    orig_win = orig_win,
    closed = false,
    spinner_timer = nil,
    diff_win = nil,
    diff_buf = nil,
    out_win = nil,
    out_buf = nil,
    max_out_height = 0,
    out_row = 0,
    out_col = 0,
  }

  local width = math.floor(vim.o.columns * opts.width_ratio)
  local height = math.floor(vim.o.lines * opts.height_ratio)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local prompt_line = '(' .. opts.prompt .. ')'
  local placeholder = {}
  if opts.model then
    table.insert(placeholder, '[model: ' .. opts.model .. ']')
  end
  table.insert(placeholder, prompt_line)

  function state:stop_spinner()
    if self.spinner_timer then
      pcall(function()
        self.spinner_timer:stop()
        self.spinner_timer:close()
      end)
      self.spinner_timer = nil
    end
    if not self.closed and vim.api.nvim_win_is_valid(self.out_win) then
      pcall(vim.api.nvim_win_set_config, self.out_win, { title = ' Generated Commit Message ', title_pos = 'center' })
    end
  end

  function state:cleanup()
    if self.closed then return end
    self.closed = true
    pcall(function() self:stop_spinner() end)
    for _, w in ipairs({ self.out_win, self.diff_win }) do
      if w and vim.api.nvim_win_is_valid(w) then
        pcall(vim.api.nvim_win_hide, w)
      end
    end
    for _, b in ipairs({ self.diff_buf, self.out_buf }) do
      if b and vim.api.nvim_buf_is_valid(b) then pcall(vim.api.nvim_buf_delete, b, { force = true }) end
    end
    if vim.api.nvim_win_is_valid(self.orig_win) then
      pcall(vim.api.nvim_set_current_win, self.orig_win)
    end
    vim.cmd('redraw!')
  end

  function state:insert_commit()
    local lines = vim.api.nvim_buf_get_lines(self.out_buf, 0, -1, false)
    while #lines > 0 and lines[1] == '' do table.remove(lines, 1) end
    while #lines > 0 and lines[#lines] == '' do table.remove(lines, #lines) end
    self:cleanup()
    if vim.api.nvim_win_is_valid(self.orig_win) then
      vim.api.nvim_set_current_win(self.orig_win)
      local cursor = vim.api.nvim_win_get_cursor(self.orig_win)
      vim.api.nvim_buf_set_lines(self.orig_buf, cursor[1] - 1, cursor[1] - 1, false, lines)
    end
  end

  function state:append_output(data)
    if not vim.api.nvim_buf_is_valid(self.out_buf) then return end
    local existing = vim.api.nvim_buf_get_lines(self.out_buf, 0, -1, false)
    for _, l in ipairs(existing) do
      if l == prompt_line then
        vim.api.nvim_buf_set_lines(self.out_buf, 0, -1, false, {})
        break
      end
    end
    local append = vim.split(data, '\n')
    if append[#append] == '' then table.remove(append) end
    if #append > 0 then
      local cur = vim.api.nvim_buf_get_lines(self.out_buf, 0, -1, false)
      vim.list_extend(cur, append)
      vim.api.nvim_set_option_value('modifiable', true, { buf = self.out_buf })
      vim.api.nvim_buf_set_lines(self.out_buf, 0, -1, false, cur)
      vim.api.nvim_set_option_value('modifiable', false, { buf = self.out_buf })
    end
    self:resize_output()
  end

  function state:finalize_output(lines)
    if not vim.api.nvim_buf_is_valid(self.out_buf) then return end
    vim.api.nvim_set_option_value('modifiable', true, { buf = self.out_buf })
    vim.api.nvim_buf_set_lines(self.out_buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value('modifiable', false, { buf = self.out_buf })
    self:resize_output()
  end

  function state:resize_output()
    if not vim.api.nvim_win_is_valid(self.out_win) then return end
    local line_count = vim.api.nvim_buf_line_count(self.out_buf)
    local new_height = math.max(1, math.min(line_count, self.max_out_height))
    if new_height ~= vim.api.nvim_win_get_height(self.out_win) then
      vim.api.nvim_win_set_config(self.out_win, { relative = 'editor', row = self.out_row, col = self.out_col, height = new_height })
    end
  end

  local function set_keymaps(buf)
    vim.keymap.set('n', 'q', function() state:cleanup() end, { buffer = buf, nowait = true, desc = 'Close' })
    vim.keymap.set('n', '<Esc>', function() state:cleanup() end, { buffer = buf, nowait = true, desc = 'Close' })
    vim.keymap.set('n', '<CR>', function() state:insert_commit() end, { buffer = buf, nowait = true, desc = 'Insert commit message and close' })
    vim.keymap.set('n', 'y', function() state:insert_commit() end, { buffer = buf, nowait = true, desc = 'Accept and insert' })
    vim.keymap.set('n', '<C-d>', '<C-d>', { buffer = buf, desc = 'Scroll down' })
    vim.keymap.set('n', '<C-u>', '<C-u>', { buffer = buf, desc = 'Scroll up' })
    vim.keymap.set('n', '<C-f>', '<C-f>', { buffer = buf, desc = 'Page down' })
    vim.keymap.set('n', '<C-b>', '<C-b>', { buffer = buf, desc = 'Page up' })
  end

  local out_height, out_row
  if opts.show_diff then
    local half_height = math.floor(height / 2)

    state.diff_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(state.diff_buf, 0, -1, false, diff)
    vim.api.nvim_set_option_value('filetype', 'diff', { buf = state.diff_buf })
    vim.api.nvim_set_option_value('modifiable', false, { buf = state.diff_buf })
    vim.api.nvim_set_option_value('buftype', 'nofile', { buf = state.diff_buf })

    state.diff_win = vim.api.nvim_open_win(state.diff_buf, true, {
      relative = 'editor',
      width = width,
      height = half_height - 1,
      row = row,
      col = col,
      border = opts.border,
      title = ' Staged Diff ',
      title_pos = 'center',
      style = 'minimal',
    })
    vim.api.nvim_set_option_value('wrap', false, { win = state.diff_win })
    vim.api.nvim_set_option_value('cursorline', true, { win = state.diff_win })
    vim.wo[state.diff_win].winhighlight = 'FloatBorder:GitcommitBorder,FloatTitle:GitcommitTitle,NormalFloat:GitcommitNormal,CursorLine:GitcommitCursorLine'
    if opts.fold_diff then
      vim.wo[state.diff_win].foldmethod = 'expr'
      vim.wo[state.diff_win].foldexpr = 'v:lua.require("gitcommit.ui").diff_foldexpr(v:lnum)'
      vim.wo[state.diff_win].foldenable = true
    end
    set_keymaps(state.diff_buf)

    out_height = height - half_height
    out_row = row + half_height + 1
  else
    out_height = height
    out_row = row
  end

  state.out_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(state.out_buf, 0, -1, false, placeholder)
  vim.api.nvim_set_option_value('filetype', 'gitcommit', { buf = state.out_buf })
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = state.out_buf })

  state.max_out_height = out_height
  state.out_row = out_row
  state.out_col = col

  state.out_win = vim.api.nvim_open_win(state.out_buf, not opts.show_diff, {
    relative = 'editor',
    width = width,
    height = math.min(#placeholder, out_height),
    row = out_row,
    col = col,
    border = opts.border,
    title = ' Generated Commit Message ',
    title_pos = 'center',
    style = 'minimal',
  })
  vim.api.nvim_set_option_value('wrap', true, { win = state.out_win })
  vim.api.nvim_set_option_value('cursorline', true, { win = state.out_win })
  vim.wo[state.out_win].winhighlight = 'FloatBorder:GitcommitBorder,FloatTitle:GitcommitTitle,NormalFloat:GitcommitNormal,CursorLine:GitcommitCursorLine'
  vim.wo[state.out_win].foldenable = false
  set_keymaps(state.out_buf)

  local spinner_idx = 1
  state.spinner_timer = vim.uv.new_timer()
  state.spinner_timer:start(0, 80, function()
    vim.schedule(function()
      if state.closed or not vim.api.nvim_win_is_valid(state.out_win) then return end
      local frame = spinner_frames[spinner_idx]
      spinner_idx = spinner_idx % #spinner_frames + 1
      vim.api.nvim_win_set_config(state.out_win, { title = ' ' .. frame .. ' Generating Commit Message ', title_pos = 'center' })
    end)
  end)

  return state
end

return M
