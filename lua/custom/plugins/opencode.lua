vim.pack.add({
  {
    src = "https://github.com/nickjvandyke/opencode.nvim",
  },
})

vim.o.autoread = true -- Required for `vim.g.opencode_opts.events.reload`

local opencode = require("opencode")

local function ask() return opencode.ask("@this: ") end
local function select() return opencode.select() end
local function operator(expr) return function() return opencode.operator(expr) end end

vim.keymap.set({ "n", "x" }, "<leader>oa", ask,                    { desc = "Ask OpenCode…" })
vim.keymap.set({ "n", "x" }, "<leader>os", select,                 { desc = "Select OpenCode…" })
vim.keymap.set({ "n", "x" }, "go",       operator("@this "),       { desc = "Append range to OpenCode", expr = true })
vim.keymap.set("n",          "goo",       function() return operator("@this ")() .. "_" end, { desc = "Append line to OpenCode", expr = true })

vim.keymap.set("n", "<S-C-k>", function() require("opencode").command("session.half.page.up") end,   { desc = "Scroll OpenCode up" })
vim.keymap.set("n", "<S-C-j>", function() require("opencode").command("session.half.page.down") end, { desc = "Scroll OpenCode down" })
