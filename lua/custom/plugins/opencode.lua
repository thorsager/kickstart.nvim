vim.pack.add({
  {
    src = "https://github.com/nickjvandyke/opencode.nvim",
    version = vim.version.range("*"), -- Latest stable release
  },
})

-- ---@type opencode.Opts
-- vim.g.opencode_opts = {
--   contexts = {
--     ["@staged"] = function(ctx)
--       local handle = io.popen("git diff --cached 2>/dev/null")
--       if not handle then return nil end
--       local result = handle:read("*a")
--       handle:close()
--       if result == "" then return nil end
--       return "Staged changes:\n" .. result
--     end,
--   },
--   select = {
--     prompts = {
--       review_staged = "Review my staged changes for any issues: @staged",
--       commit_msg = "Write a commit message for these staged changes: @staged",
--     },
--   },
-- }
--
vim.o.autoread = true -- Required for `vim.g.opencode_opts.events.reload`

-- Recommended/example keymaps
vim.keymap.set({ "n", "x" }, "<leader>oa", function() require("opencode").ask("@this: ") end, { desc = "Ask OpenCode…" })
vim.keymap.set({ "n", "x" }, "<leader>os", function() require("opencode").select() end,       { desc = "Select OpenCode…" })

vim.keymap.set({ "n", "x" }, "go",  function() return require("opencode").operator("@this ") end,        { desc = "Append range to OpenCode", expr = true })
vim.keymap.set("n",          "goo", function() return require("opencode").operator("@this ") .. "_" end, { desc = "Append line to OpenCode", expr = true })

vim.keymap.set("n", "<S-C-k>", function() require("opencode").command("session.half.page.up") end,   { desc = "Scroll OpenCode up" })
vim.keymap.set("n", "<S-C-j>", function() require("opencode").command("session.half.page.down") end, { desc = "Scroll OpenCode down" })

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("OpencodeCommitMsg", { clear = true }),
  pattern = "gitcommit",
  callback = function(args)
    vim.keymap.set("n", "<leader>oc", function()
      require("opencode").prompt("Run `git diff --cached` to see the staged changes, then write a commit message following the Conventional Commits specification. Use the format `<type>(<optional scope>): <subject>` where type is one of: feat, fix, docs, style, refactor, perf, test, build, ci, chore, or revert. The subject line must be lowercase, imperative mood, no trailing period, and max 72 characters. If the changes warrant it, add a body wrapped at 72 columns explaining what changed and why — focus on the motivation, not the mechanics. Do not include a footer unless there is a breaking change (use `BREAKING CHANGE:` footer) or issue reference. Do not explain your reasoning or summarize what you did. Just run the command, write the commit message, and edit @this to contain only the commit message, preserving the commented lines.")
    end, { buffer = args.buf, desc = "OpenCode: Generate commit message" })
  end,
})
