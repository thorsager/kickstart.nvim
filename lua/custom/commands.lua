-- Custom commands for Neovim
-- Maven Test Runner - Run Java tests at cursor position

-- Configuration
local config = {
  split_direction = 'horizontal', -- 'horizontal' or 'vertical'
  lsp_timeout = 1000, -- LSP timeout in milliseconds
  maven_command = 'mvn', -- Fallback Maven command if mvnw not found
  test_suffix_pattern = 'Test%.java$', -- Pattern to identify test files
  debug = false, -- Enable debug output (set to true to see debug messages)
  auto_scroll_default = true, -- Enable auto-scroll by default (set to false to disable)
  lsp_retry_count = 2, -- Number of retries for LSP symbol detection
  lsp_retry_delay = 500, -- Delay between retries in milliseconds
}

-- Table to track auto-scroll state per buffer
-- Structure: { [bufnr] = { enabled = true, win = win_id } }
local auto_scroll_state = {}

-- Helper function for debug logging
local function debug_log(message)
  if config.debug then vim.notify('[DEBUG] ' .. message, vim.log.levels.INFO) end
end

-- Helper function to check if file is a test file
local function is_test_file(filepath) return filepath:match(config.test_suffix_pattern) ~= nil end

-- Helper function to find Maven project root by looking for pom.xml
local function find_maven_project_root(filepath)
  local dir = vim.fn.fnamemodify(filepath, ':p:h')

  -- Walk up directory tree looking for pom.xml
  while dir ~= '/' do
    if vim.fn.filereadable(dir .. '/pom.xml') == 1 then return dir end
    dir = vim.fn.fnamemodify(dir, ':h')
  end

  return nil
end

-- Helper function to detect Maven Wrapper or fall back to system Maven
local function get_maven_command(project_root)
  -- Check for Maven Wrapper (Unix/Mac)
  local mvnw_unix = project_root .. '/mvnw'
  if vim.fn.executable(mvnw_unix) == 1 then return './mvnw' end

  -- Check for Maven Wrapper (Windows)
  local mvnw_windows = project_root .. '/mvnw.cmd'
  if vim.fn.executable(mvnw_windows) == 1 then return './mvnw.cmd' end

  -- Fall back to configured Maven command
  return config.maven_command
end

-- Helper function to build Maven test command
local function build_maven_test_command(project_root, class_name, method_name)
  local maven_cmd = get_maven_command(project_root)
  local test_spec

  if method_name then
    -- Cursor is in a method - run specific test method
    test_spec = string.format('%s#%s', class_name, method_name)
  else
    -- Cursor is in class but not in method - run all tests in class
    test_spec = class_name
  end

  return string.format('%s test -Dtest=%s', maven_cmd, test_spec)
end

-- Scroll window to bottom if auto-scroll is enabled
local function scroll_to_bottom(buf)
  local state = auto_scroll_state[buf]
  if not state or not state.enabled then return end

  local win = state.win
  if not vim.api.nvim_win_is_valid(win) then return end

  local line_count = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_win_set_cursor(win, { line_count, 0 })
end

-- Update the auto-scroll status indicator in the buffer header
local function update_scroll_status(buf)
  local state = auto_scroll_state[buf]
  if not state or not vim.api.nvim_buf_is_valid(buf) then return end

  -- Status line is at line 3 (after title and separator)
  local status_text
  if state.enabled then
    status_text = 'Auto-scroll: ✅ ON  (scroll up to pause, press f to follow)'
  else
    status_text = 'Auto-scroll: ⏸️  OFF (press f to follow output)'
  end

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) then
      local was_modifiable = vim.bo[buf].modifiable
      vim.bo[buf].modifiable = true
      vim.api.nvim_buf_set_lines(buf, 2, 3, false, { status_text })
      vim.bo[buf].modifiable = was_modifiable
    end
  end)
end

-- Function to get Java test context (class and method) at cursor position using LSP
local function get_java_test_context()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1 -- 0-indexed
  local col = cursor[2]

  -- Check if jdtls is attached to the buffer
  local clients = vim.lsp.get_clients { bufnr = bufnr, name = 'jdtls' }
  if #clients == 0 then
    debug_log 'jdtls is not running, will use filename fallback'
    return { class = nil, method = nil }
  end

  -- Helper to attempt LSP symbol request
  local function attempt_lsp_symbol_request(buf, params)
    local result = vim.lsp.buf_request_sync(buf, 'textDocument/documentSymbol', params, config.lsp_timeout)
    
    if not result or vim.tbl_isempty(result) then
      return nil
    end
    
    -- Extract symbols from the first client that responded
    for _, res in pairs(result) do
      if res.result and #res.result > 0 then
        return res.result
      end
    end
    
    return nil
  end

  -- Prepare LSP document symbol request
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
  }

  -- Make LSP request with retry logic
  local symbols = nil
  local max_attempts = config.lsp_retry_count + 1

  for attempt = 1, max_attempts do
    debug_log('LSP symbol detection attempt ' .. attempt .. ' of ' .. max_attempts)
    
    symbols = attempt_lsp_symbol_request(bufnr, params)
    
    if symbols then
      debug_log('LSP returned ' .. #symbols .. ' symbols on attempt ' .. attempt)
      break
    end
    
    -- If this is not the last attempt, show warning and wait
    if attempt < max_attempts then
      vim.notify(
        string.format('LSP symbol detection failed, retrying... (attempt %d of %d)', attempt, max_attempts),
        vim.log.levels.WARN
      )
      vim.wait(config.lsp_retry_delay)
    end
  end

  if not symbols then
    debug_log('LSP did not return symbols after ' .. max_attempts .. ' attempts')
    return { class = nil, method = nil }
  end

  -- Debug: log symbols structure
  debug_log('Found ' .. #symbols .. ' top-level symbols')

  -- Debug: show full LSP response structure if no symbols found
  if config.debug and #symbols == 0 then debug_log('Full LSP result structure: ' .. vim.inspect(result)) end

  -- Debug: show first symbol structure if available
  if config.debug and #symbols > 0 then debug_log('First symbol: name=' .. tostring(symbols[1].name) .. ', kind=' .. tostring(symbols[1].kind)) end

  -- Helper function to check if cursor is within a symbol's range
  local function is_cursor_in_range(range)
    -- LSP range is 0-indexed
    local start_line = range.start.line
    local end_line = range['end'].line
    local start_char = range.start.character
    local end_char = range['end'].character

    if row < start_line or row > end_line then return false end
    if row == start_line and col < start_char then return false end
    if row == end_line and col > end_char then return false end
    return true
  end

  -- Helper function to recursively search for class and method
  local function find_context(symbol_list, class_name, method_name, depth)
    depth = depth or 0

    for _, symbol in ipairs(symbol_list) do
      local range = symbol.range or (symbol.location and symbol.location.range)

      if not range then
        debug_log('Symbol missing range: ' .. symbol.name)
        goto continue
      end

      if is_cursor_in_range(range) then
        -- SymbolKind: Class=5, Method=6, Constructor=9, Interface=11, Enum=10
        if symbol.kind == 5 or symbol.kind == 11 or symbol.kind == 10 then
          -- This is a class, interface, or enum
          class_name = symbol.name
          debug_log('Found class: ' .. class_name .. ' at depth ' .. depth)
        elseif symbol.kind == 6 or symbol.kind == 9 then
          -- This is a method or constructor
          -- Strip parentheses from method name (e.g., "myMethod()" -> "myMethod")
          method_name = symbol.name:gsub('%(%)', '')
          debug_log('Found method: ' .. method_name .. ' at depth ' .. depth)
        end

        -- Recursively search children
        if symbol.children and #symbol.children > 0 then
          class_name, method_name = find_context(symbol.children, class_name, method_name, depth + 1)
        end
      end

      ::continue::
    end

    return class_name, method_name
  end

  local class_name, method_name = find_context(symbols, nil, nil)

  return {
    class = class_name,
    method = method_name,
  }
end

-- Main function to run Maven test for class/method at cursor
local function run_command_on_file()
  debug_log 'Starting run_command_on_file'

  -- Check if current buffer is a Java file
  local filetype = vim.bo.filetype
  debug_log('File type: ' .. tostring(filetype))

  if filetype ~= 'java' then
    vim.notify('This command only works with Java files', vim.log.levels.WARN)
    return
  end

  -- Get the current file path (relative)
  local filepath = vim.fn.expand '%'
  debug_log('Filepath: ' .. tostring(filepath))

  -- Check if we have a valid file
  if filepath == '' or filepath == nil then
    vim.notify('No file in current buffer', vim.log.levels.WARN)
    return
  end

  -- Check if this is a test file
  if not is_test_file(filepath) then
    vim.notify('This file is not a test file. Test files should match pattern: *Test.java', vim.log.levels.WARN)
    return
  end
  debug_log 'File is a test file'

  -- Get Java test context (class and method at cursor) using LSP
  debug_log 'Calling get_java_test_context()'
  local context = get_java_test_context()
  debug_log('Context returned: class=' .. tostring(context.class) .. ', method=' .. tostring(context.method))

  -- If LSP didn't find class, try to extract from filename as fallback
  if not context.class then
    debug_log 'No class found via LSP, using filename fallback'
    -- Extract class name from filename (e.g., MyServiceTest.java -> MyServiceTest)
    local filename = vim.fn.fnamemodify(filepath, ':t:r')
    debug_log('Extracted filename: ' .. tostring(filename))
    if filename and filename ~= '' then
      context.class = filename
      vim.notify('Using class name from filename: ' .. filename, vim.log.levels.INFO)
    else
      vim.notify('Could not determine test class at cursor position', vim.log.levels.ERROR)
      return
    end
  else
    debug_log('Found class via LSP: ' .. context.class)
  end

  -- Find Maven project root
  local project_root = find_maven_project_root(filepath)
  if not project_root then
    vim.notify('Could not find pom.xml in parent directories. Are you in a Maven project?', vim.log.levels.ERROR)
    return
  end

  -- Build Maven test command
  local maven_cmd = build_maven_test_command(project_root, context.class, context.method)

  -- Create a new split window
  if config.split_direction == 'vertical' then
    vim.cmd 'vsplit'
  else
    vim.cmd 'split'
  end

  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  -- Prepare header content
  local auto_scroll_status = config.auto_scroll_default and 'Auto-scroll: ✅ ON  (scroll up to pause, press f to follow)'
    or 'Auto-scroll: ⏸️  OFF (press f to follow output)'

  local header_lines = {
    'Maven Test Runner',
    string.rep('═', 80),
    auto_scroll_status,
    '',
    'File:    ' .. filepath,
    'Class:   ' .. context.class,
    'Method:  ' .. (context.method or '<all tests in class>'),
    'Command: ' .. maven_cmd,
    '',
    string.rep('─', 80),
    '',
  }

  -- Set header content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, header_lines)

  -- Initialize auto-scroll state
  auto_scroll_state[buf] = {
    enabled = config.auto_scroll_default,
    win = win,
  }

  -- Detect when user manually scrolls
  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = buf,
    callback = function()
      local state = auto_scroll_state[buf]
      if not state or not state.enabled then return end

      -- Check if cursor moved away from bottom
      local cursor_line = vim.api.nvim_win_get_cursor(win)[1]
      local total_lines = vim.api.nvim_buf_line_count(buf)

      -- If user scrolled up (even 1 line), disable auto-scroll
      if cursor_line < total_lines then
        state.enabled = false
        update_scroll_status(buf)
      end
    end,
  })

  -- Cleanup auto-scroll state when buffer is deleted
  vim.api.nvim_create_autocmd('BufDelete', {
    buffer = buf,
    callback = function() auto_scroll_state[buf] = nil end,
  })

  -- Track line count for appending output
  local line_count = #header_lines

  -- Run Maven command and capture output
  local job_id = vim.fn.jobstart(maven_cmd, {
    cwd = project_root,
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data, _)
      if data and vim.api.nvim_buf_is_valid(buf) then
        vim.schedule(function()
          vim.bo[buf].modifiable = true
          -- Filter out empty strings
          local lines = vim.tbl_filter(function(line) return line ~= '' end, data)
          if #lines > 0 then
            vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, lines)
            line_count = line_count + #lines
          end
          vim.bo[buf].modifiable = false

          -- Auto-scroll to bottom if enabled
          scroll_to_bottom(buf)
        end)
      end
    end,
    on_stderr = function(_, data, _)
      if data and vim.api.nvim_buf_is_valid(buf) then
        vim.schedule(function()
          vim.bo[buf].modifiable = true
          -- Filter out empty strings
          local lines = vim.tbl_filter(function(line) return line ~= '' end, data)
          if #lines > 0 then
            vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, lines)
            line_count = line_count + #lines
          end
          vim.bo[buf].modifiable = false

          -- Auto-scroll to bottom if enabled
          scroll_to_bottom(buf)
        end)
      end
    end,
    on_exit = function(_, exit_code, _)
      -- Update header with result
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) then
          vim.bo[buf].modifiable = true

          local result_line
          if exit_code == 0 then
            result_line = '✅ Maven Test Runner - PASSED'
          else
            result_line = '❌ Maven Test Runner - FAILED'
          end

          vim.api.nvim_buf_set_lines(buf, 0, 1, false, { result_line })
          vim.bo[buf].modifiable = false
        end
      end)
    end,
  })

  -- Check if job started successfully
  if job_id == 0 then
    vim.notify('Failed to start job', vim.log.levels.ERROR)
    return
  elseif job_id == -1 then
    vim.notify('Invalid command: ' .. maven_cmd, vim.log.levels.ERROR)
    return
  end

  -- Set buffer options
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'maventest'

  -- Set buffer name for identification
  local test_name = context.method or context.class
  vim.api.nvim_buf_set_name(buf, 'Maven Test: ' .. test_name)

  -- Setup syntax highlighting for test results
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) then
      -- Define custom highlights
      vim.api.nvim_set_hl(0, 'TestSuccess', { fg = '#00ff00', bold = true })
      vim.api.nvim_set_hl(0, 'TestFailure', { fg = '#ff0000', bold = true })
      vim.api.nvim_set_hl(0, 'TestRunning', { fg = '#ffff00', bold = true })

      -- Apply syntax patterns
      vim.api.nvim_buf_call(buf, function()
        vim.cmd [[syntax match TestSuccess /BUILD SUCCESS/]]
        vim.cmd [[syntax match TestSuccess /Tests run:.*, Failures: 0, Errors: 0/]]
        vim.cmd [[syntax match TestFailure /BUILD FAILURE/]]
        vim.cmd [[syntax match TestFailure /FAILURE!/]]
        vim.cmd [[syntax match TestFailure /Tests run:.*, Failures: [1-9]/]]
        vim.cmd [[syntax match TestFailure /Tests run:.*, Errors: [1-9]/]]
        vim.cmd [[syntax match TestRunning /Running .*/]]
        vim.cmd [[syntax match TestRunning /\[INFO\]/]]
        -- Syntax for auto-scroll status
        vim.cmd [[syntax match TestSuccess /Auto-scroll: ✅ ON/]]
        vim.cmd [[syntax match TestFailure /Auto-scroll: ⏸️  OFF/]]
      end)
    end
  end)

  -- Set up keymaps to close the window with q and Esc
  local opts = { noremap = true, silent = true, buffer = buf }
  vim.keymap.set('n', 'q', '<cmd>close<CR>', opts)
  vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', opts)

  -- Re-enable auto-scroll with 'f' (follow)
  vim.keymap.set('n', 'f', function()
    local state = auto_scroll_state[buf]
    if state then
      state.enabled = true
      update_scroll_status(buf)
      scroll_to_bottom(buf)
      vim.notify('Auto-scroll enabled', vim.log.levels.INFO)
    end
  end, opts)
end

-- Function to run a Maven command (generic)
local function run_maven_command(maven_args, command_description)
  -- Get the current file path to find project root
  local filepath = vim.fn.expand '%'

  -- Find Maven project root
  local project_root = find_maven_project_root(filepath)
  if not project_root then
    vim.notify('Could not find pom.xml in parent directories. Are you in a Maven project?', vim.log.levels.ERROR)
    return
  end

  -- Build Maven command
  local maven_cmd = get_maven_command(project_root) .. ' ' .. maven_args

  -- Create a new split window
  if config.split_direction == 'vertical' then
    vim.cmd 'vsplit'
  else
    vim.cmd 'split'
  end

  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  -- Prepare header content
  local auto_scroll_status = config.auto_scroll_default and 'Auto-scroll: ✅ ON  (scroll up to pause, press f to follow)'
    or 'Auto-scroll: ⏸️  OFF (press f to follow output)'

  local header_lines = {
    'Maven: ' .. command_description,
    string.rep('═', 80),
    auto_scroll_status,
    '',
    'Command: ' .. maven_cmd,
    'Working Directory: ' .. project_root,
    '',
    string.rep('─', 80),
    '',
  }

  -- Set header content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, header_lines)

  -- Initialize auto-scroll state
  auto_scroll_state[buf] = {
    enabled = config.auto_scroll_default,
    win = win,
  }

  -- Detect when user manually scrolls
  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = buf,
    callback = function()
      local state = auto_scroll_state[buf]
      if not state or not state.enabled then return end

      -- Check if cursor moved away from bottom
      local cursor_line = vim.api.nvim_win_get_cursor(win)[1]
      local total_lines = vim.api.nvim_buf_line_count(buf)

      -- If user scrolled up (even 1 line), disable auto-scroll
      if cursor_line < total_lines then
        state.enabled = false
        update_scroll_status(buf)
      end
    end,
  })

  -- Cleanup auto-scroll state when buffer is deleted
  vim.api.nvim_create_autocmd('BufDelete', {
    buffer = buf,
    callback = function() auto_scroll_state[buf] = nil end,
  })

  -- Track line count for appending output
  local line_count = #header_lines

  -- Run Maven command and capture output
  local job_id = vim.fn.jobstart(maven_cmd, {
    cwd = project_root,
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data, _)
      if data and vim.api.nvim_buf_is_valid(buf) then
        vim.schedule(function()
          vim.bo[buf].modifiable = true
          local lines = vim.tbl_filter(function(line) return line ~= '' end, data)
          if #lines > 0 then
            vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, lines)
            line_count = line_count + #lines
          end
          vim.bo[buf].modifiable = false

          -- Auto-scroll to bottom if enabled
          scroll_to_bottom(buf)
        end)
      end
    end,
    on_stderr = function(_, data, _)
      if data and vim.api.nvim_buf_is_valid(buf) then
        vim.schedule(function()
          vim.bo[buf].modifiable = true
          local lines = vim.tbl_filter(function(line) return line ~= '' end, data)
          if #lines > 0 then
            vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, lines)
            line_count = line_count + #lines
          end
          vim.bo[buf].modifiable = false

          -- Auto-scroll to bottom if enabled
          scroll_to_bottom(buf)
        end)
      end
    end,
    on_exit = function(_, exit_code, _)
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) then
          vim.bo[buf].modifiable = true

          local result_line
          if exit_code == 0 then
            result_line = '✅ Maven: ' .. command_description .. ' - SUCCESS'
          else
            result_line = '❌ Maven: ' .. command_description .. ' - FAILED'
          end

          vim.api.nvim_buf_set_lines(buf, 0, 1, false, { result_line })
          vim.bo[buf].modifiable = false
        end
      end)
    end,
  })

  -- Check if job started successfully
  if job_id == 0 then
    vim.notify('Failed to start job', vim.log.levels.ERROR)
    return
  elseif job_id == -1 then
    vim.notify('Invalid command: ' .. maven_cmd, vim.log.levels.ERROR)
    return
  end

  -- Set buffer options
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'mavenoutput'

  -- Set buffer name
  vim.api.nvim_buf_set_name(buf, 'Maven: ' .. command_description)

  -- Setup syntax highlighting
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_set_hl(0, 'MavenSuccess', { fg = '#00ff00', bold = true })
      vim.api.nvim_set_hl(0, 'MavenFailure', { fg = '#ff0000', bold = true })
      vim.api.nvim_set_hl(0, 'MavenInfo', { fg = '#ffff00', bold = true })

      vim.api.nvim_buf_call(buf, function()
        vim.cmd [[syntax match MavenSuccess /BUILD SUCCESS/]]
        vim.cmd [[syntax match MavenFailure /BUILD FAILURE/]]
        vim.cmd [[syntax match MavenInfo /\[INFO\]/]]
        -- Syntax for auto-scroll status
        vim.cmd [[syntax match MavenSuccess /Auto-scroll: ✅ ON/]]
        vim.cmd [[syntax match MavenFailure /Auto-scroll: ⏸️  OFF/]]
      end)
    end
  end)

  -- Set up keymaps
  local opts = { noremap = true, silent = true, buffer = buf }
  vim.keymap.set('n', 'q', '<cmd>close<CR>', opts)
  vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', opts)

  -- Re-enable auto-scroll with 'f' (follow)
  vim.keymap.set('n', 'f', function()
    local state = auto_scroll_state[buf]
    if state then
      state.enabled = true
      update_scroll_status(buf)
      scroll_to_bottom(buf)
      vim.notify('Auto-scroll enabled', vim.log.levels.INFO)
    end
  end, opts)
end

-- Create the user commands
vim.api.nvim_create_user_command('MavenTest', run_command_on_file, {
  desc = 'Run Maven test for the Java test class/method at cursor position with live output',
})

vim.api.nvim_create_user_command('MavenClean', function() run_maven_command('clean', 'Clean') end, {
  desc = 'Run Maven clean to remove target directory and build artifacts',
})

vim.api.nvim_create_user_command('MavenCompileAll', function() run_maven_command('compile', 'Compile') end, {
  desc = 'Run Maven compile to build class files for the entire project',
})

vim.api.nvim_create_user_command('MavenVerifyAll', function() run_maven_command('verify', 'Verify') end, {
  desc = 'Run Maven verify on the entire project',
})

vim.api.nvim_create_user_command('MavenTestAll', function() run_maven_command('test', 'Test') end, {
  desc = 'Run Maven test on the entire project',
})
