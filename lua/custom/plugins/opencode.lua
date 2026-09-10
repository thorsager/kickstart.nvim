vim.pack.add({
  {
    src = "https://github.com/nickjvandyke/opencode.nvim",
    version = vim.version.range("*"), -- Latest stable release
  },
})

vim.o.autoread = true -- Required for `vim.g.opencode_opts.events.reload`

-- Recommended/example keymaps
vim.keymap.set({ "n", "x" }, "<leader>oa", function() require("opencode").ask("@this: ") end, { desc = "Ask OpenCode…" })
vim.keymap.set({ "n", "x" }, "<leader>os", function() require("opencode").select() end,       { desc = "Select OpenCode…" })

vim.keymap.set({ "n", "x" }, "go",  function() return require("opencode").operator("@this ") end,        { desc = "Append range to OpenCode", expr = true })
vim.keymap.set("n",          "goo", function() return require("opencode").operator("@this ") .. "_" end, { desc = "Append line to OpenCode", expr = true })

vim.keymap.set("n", "<S-C-k>", function() require("opencode").command("session.half.page.up") end,   { desc = "Scroll OpenCode up" })
vim.keymap.set("n", "<S-C-j>", function() require("opencode").command("session.half.page.down") end, { desc = "Scroll OpenCode down" })

-- Monkey-patch the edit diff handler (once) so that edits to a gitcommit buffer
-- are applied in-memory (rejecting the file write) instead of opening a diff tab.
-- Other files still get the built-in diff view.
local _diff_patched = false
local function setup_diff_intercept()
  if _diff_patched then return end
  _diff_patched = true

  local edits = require("opencode.events.permissions.edits")
  local orig_diff = edits.diff
  local Promise = require("opencode.promise")

  edits.diff = function(event)
    if
      event.type == "permission.asked"
      and event.properties.permission == "edit"
      and event.properties.metadata
    then
      local filepath = event.properties.metadata.filepath
      local absolute = vim.fn.fnamemodify(filepath, ":p")
      if vim.fn.filereadable(absolute) == 1 then filepath = absolute end
      local target = vim.fs.normalize(filepath)

      -- Find a valid gitcommit buffer whose name matches the edit target
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(b) and vim.bo[b].filetype == "gitcommit" then
          local bname = vim.fs.normalize(vim.api.nvim_buf_get_name(b))
          if bname == target then
            local diff = event.properties.metadata.diff
            local patch_file = vim.fn.tempname() .. ".patch"
            local orig_file = vim.fn.tempname()
            local out_file = orig_file .. ".out"

            vim.fn.writefile(vim.split(diff, "\n"), patch_file)
            vim.fn.writefile(vim.api.nvim_buf_get_lines(b, 0, -1, false), orig_file)

            vim.system({ "patch", "-s", "-o", out_file, orig_file, patch_file }):wait()

            if vim.fn.filereadable(out_file) == 1 then
              vim.api.nvim_buf_set_lines(b, 0, -1, false, vim.fn.readfile(out_file))
            end

            os.remove(patch_file)
            os.remove(orig_file)
            os.remove(out_file)

            return Promise.resolve("reject")
          end
        end
      end
    end

    return orig_diff(event)
  end
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("OpencodeCommitMsg", { clear = true }),
  pattern = "gitcommit",
  callback = function(args)
    local buf = args.buf

    vim.keymap.set("n", "<leader>oc", function()
      require("opencode").prompt("Run `git diff --cached` to see the staged changes, then write a commit message following the Conventional Commits specification. Use the format `<type>(<optional scope>): <subject>` where type is one of: feat, fix, docs, style, refactor, perf, test, build, ci, chore, or revert. The subject line must be lowercase, imperative mood, no trailing period, and max 72 characters. If the changes warrant it, add a body wrapped at 72 columns explaining what changed and why — focus on the motivation, not the mechanics. Do not include a footer unless there is a breaking change (use `BREAKING CHANGE:` footer) or issue reference. Do not explain your reasoning or summarize what you did. Just run the command, write the commit message, and edit @this to contain only the commit message, preserving the commented lines.")
    end, { buffer = buf, desc = "OpenCode: Generate commit message" })

    setup_diff_intercept()
  end,
})
