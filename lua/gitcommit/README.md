# gitcommit.nvim

Generate commit messages from staged git diffs using an AI CLI agent.

## Requirements

- Neovim 0.10+
- An AI CLI binary that reads a prompt from stdin and writes the response to stdout (defaults to [`pi`](https://github.com/anthropics/pi))

## Installation

### Using `lazy.nvim`

```lua
{
  'your-username/gitcommit.nvim',
  dir = vim.fn.stdpath('config') .. '/lua/gitcommit',
  ft = 'gitcommit',
  config = function()
    require('gitcommit').setup()
  end,
}
```

### Manual

Place the `gitcommit` directory inside your `lua/` directory and call setup:

```lua
require('gitcommit').setup()
```

## Usage

Open a git commit buffer (`git commit`), then press the configured keymap (default: `<leader>xc`) to generate a commit message from the staged diff.

### Preview Mode (default)

When `preview = true`, two floating windows appear:
- **Staged Diff** (top) — shows `git diff --cached` (if `show_diff = true`)
- **Generated Commit Message** (bottom) — streams the AI output as it arrives, auto-resizing to fit the content

| Key | Action |
|-----|--------|
| `<CR>` | Insert the commit message at cursor and close |
| `q` / `<Esc>` | Close without inserting |
| `<C-d>` / `<C-u>` | Scroll half-page down / up |
| `<C-f>` / `<C-b>` | Scroll full-page down / up |

### Direct Mode (`preview = false`)

No floating window. The commit message is generated in the background with a spinner notification and inserted directly at the cursor when complete.

## Configuration

All options are optional. Defaults are shown below.

```lua
require('gitcommit').setup({
  -- Keymap that triggers commit message generation (in gitcommit buffers)
  keymap = '<leader>xc',

  -- Show the staged diff in a floating window alongside the output
  show_diff = true,

  -- Preview the generated message in a floating window before inserting.
  -- When false, the message is inserted directly at the cursor.
  preview = true,

  -- Floating window size, as a ratio of the editor dimensions
  width_ratio = 0.85,
  height_ratio = 0.80,

  -- Floating window border style (array of 8 strings: corners + sides)
  border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },

  -- AI CLI binary name
  binary = 'pi',

  -- Model passed to the binary via `--model <model>`.
  -- When unset (nil), the `--model` argument is not added and the
  -- binary uses its own default model.
  model = nil,

  -- Arguments passed to the binary (before the system prompt and prompt)
  binary_args = {
    '--no-session',
    '--no-tools',
    '--no-context-files',
    '--no-skills',
    '--no-prompt-templates',
    '--no-extensions',
  },

  -- System prompt sent to the AI agent
  system_prompt = 'You are a commit message generator. '
    .. 'Given a staged git diff, output a commit message following the '
    .. 'commitizen convention (e.g. "feat:", "fix:", "refactor:"). '
    .. 'The subject line must be under 50 characters. '
    .. 'If a body is needed, wrap each line at 72 characters. '
    .. 'You must respond with ONLY the raw commit message — '
    .. 'no preface, no explanation, no commentary, '
    .. 'no markdown formatting, no code fences, no backticks.',

  -- Prompt sent to the AI agent (the diff is piped via stdin)
  prompt = 'Write the commit message for the staged diff provided below.',

  -- Custom command builder. When set, overrides binary + binary_args entirely.
  -- Receives the full config table and must return an array of strings.
  -- Example:
  --   build_command = function(config)
  --     return { 'aichat', '--system', config.system_prompt, config.prompt }
  --   end,
  build_command = nil,

  -- Command used to generate the diff (output is piped to the AI agent via stdin)
  diff_command = { 'git', 'diff', '--cached' },

  -- Fold diff hunks in the diff pane (each hunk collapses to its @@ header line)
  fold_diff = true,

  -- Multiple keybindings, each with its own overrides.
  -- When set, takes precedence over the single `keymap` option.
  -- Each entry merges with the defaults above; only `key` is required.
  -- Optional: `desc` sets the keymap description.
  -- keymaps = {
  --   {
  --     key = '<leader>xc',
  --     prompt = 'Write a conventional commit message for this diff.',
  --   },
  --   {
  --     key = '<leader>xv',
  --     desc = 'Generate verbose commit',
  --     system_prompt = 'Write a detailed commit message with a thorough body...',
  --     preview = false,
  --   },
  --   {
  --     key = '<leader>xa',
  --     build_command = function(config)
  --       return { 'aichat', '--system', config.system_prompt, config.prompt }
  --     end,
  --   },
  -- },
  keymaps = nil,
})
```

## Multiple Keybindings

You can define multiple keybindings, each with different prompts, commands, or
preview settings. Each entry inherits the defaults and overrides only what you
specify:

```lua
require('gitcommit').setup({
  keymaps = {
    {
      key = '<leader>xc',
      prompt = 'Write a concise commit message.',
    },
    {
      key = '<leader>xv',
      desc = 'Verbose commit',
      system_prompt = 'Write a detailed commit message with a thorough body...',
    },
    {
      key = '<leader>xa',
      preview = false,
      build_command = function(config)
        return { 'aichat', '--system', config.system_prompt, config.prompt }
      end,
    },
  },
})
```

## Custom Command Example

To use a different CLI agent entirely:

```lua
require('gitcommit').setup({
  build_command = function(config)
    return {
      'aichat',
      '--model', 'gpt-4o',
      '--system', config.system_prompt,
      config.prompt,
    }
  end,
})
```

The staged diff is always piped to the command's stdin. The command's stdout is streamed into the preview window (or collected and inserted directly in `preview = false` mode).

## License

MIT
