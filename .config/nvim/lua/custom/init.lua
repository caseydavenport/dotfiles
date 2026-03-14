---------------------------------------------------------------
-- Editor defaults
---------------------------------------------------------------

-- Line-length ruler at 160 columns.
vim.opt.colorcolumn = "160"

-- Disable swap files.
vim.opt.swapfile = false

-- Make the which-key popup larger.
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyDone",
  callback = function()
    local ok, wk = pcall(require, "which-key")
    if ok then
      wk.setup({
        win = {
          height = { min = 20, max = 50 },
        },
      })
    end
  end,
  once = true,
})

-- Fix autopairs: don't insert closing bracket when one already exists on the line.
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyDone",
  callback = function()
    local ok, autopairs = pcall(require, "nvim-autopairs")
    if ok then
      autopairs.setup({
        fast_wrap = {},
        disable_filetype = { "TelescopePrompt", "vim" },
        check_ts = true,
        enable_check_bracket_line = false,
      })
    end
  end,
})

---------------------------------------------------------------
-- Autocommands
---------------------------------------------------------------

-- Return to last edit position when opening files.
vim.api.nvim_create_autocmd("BufReadPost", {
  desc = "Return to last edit position when opening files",
  command = [[if line("'\"") > 1 && line("'\"") <= line("$") | execute "normal! g`\"" | endif]]}
)

-- Register :A to switch between .go and _test.go files (via vim-go).
vim.api.nvim_create_autocmd("Filetype", {
  desc = 'Switch between .go and _test.go files.',
  pattern = 'go',
  command = 'command! -bang A call go#alternate#Switch(<bang>0, \'edit\')'}
)

-- Trim trailing whitespace on save.
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  pattern = { "*" },
  command = [[%s/\s\+$//e]],
})

---------------------------------------------------------------
-- Language servers and diagnostics
---------------------------------------------------------------

vim.lsp.enable("gopls")

-- Show diagnostic text inline, not as virtual lines.
-- Set after a short defer to ensure it runs after any plugin overrides.
vim.defer_fn(function()
  vim.diagnostic.config({ virtual_lines = false, virtual_text = true })
end, 100)

-- Run tests in a neovim terminal split.
vim.g['test#strategy'] = "neovim"

---------------------------------------------------------------
-- Keybinding overrides
---------------------------------------------------------------


---------------------------------------------------------------
-- Claude Code floating terminal
---------------------------------------------------------------

-- Open Claude Code in a centered floating window.
vim.keymap.set("n", "<leader>ai", function()
  local width = math.floor(vim.o.columns * 0.85)
  local height = math.floor(vim.o.lines * 0.85)
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
  })
  vim.fn.termopen("claude", { on_exit = function() vim.api.nvim_win_close(win, true) end })
  vim.cmd("startinsert")
end, { desc = "Open Claude Code" })

---------------------------------------------------------------
-- Plugin keybindings: copilot
---------------------------------------------------------------

-- Toggle Copilot chat in normal and visual modes.
vim.keymap.set("n", "<leader>c", '<cmd>CopilotChatToggle<cr>', { noremap = true, silent = true })
vim.keymap.set("x", "<leader>c", '<cmd>CopilotChatToggle<cr>', { noremap = true, silent = true })

---------------------------------------------------------------
-- Plugin keybindings: trouble (diagnostics panel)
---------------------------------------------------------------

vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Diagnostics (Trouble)" })
vim.keymap.set("n", "<leader>xd", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Buffer diagnostics (Trouble)" })
vim.keymap.set("n", "<leader>xq", "<cmd>Trouble quickfix toggle<cr>", { desc = "Quickfix (Trouble)" })

---------------------------------------------------------------
-- Plugin keybindings: harpoon (file bookmarks)
---------------------------------------------------------------

vim.keymap.set("n", "<leader>ha", function() require("harpoon"):list():add() end, { desc = "Harpoon add file" })
vim.keymap.set("n", "<leader>hh", function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end, { desc = "Harpoon menu" })
vim.keymap.set("n", "<leader>1", function() require("harpoon"):list():select(1) end, { desc = "Harpoon file 1" })
vim.keymap.set("n", "<leader>2", function() require("harpoon"):list():select(2) end, { desc = "Harpoon file 2" })
vim.keymap.set("n", "<leader>3", function() require("harpoon"):list():select(3) end, { desc = "Harpoon file 3" })
vim.keymap.set("n", "<leader>4", function() require("harpoon"):list():select(4) end, { desc = "Harpoon file 4" })

---------------------------------------------------------------
-- Plugin keybindings: telescope
---------------------------------------------------------------

-- Live grep with ripgrep args (e.g., append "-t go" to only search Go files).
vim.keymap.set("n", "<leader>fg", function() require("telescope").extensions.live_grep_args.live_grep_args() end, { desc = "Live grep (with rg args)" })

---------------------------------------------------------------
-- Plugin keybindings: Go test coverage
---------------------------------------------------------------

-- Run tests and highlight covered/uncovered lines in the current file.
vim.keymap.set("n", "<leader>gcr", function() require("nvim-goc").Coverage() end, { desc = "Go coverage run" })
vim.keymap.set("n", "<leader>gcc", function() require("nvim-goc").ClearCoverage() end, { desc = "Go coverage clear" })

---------------------------------------------------------------
-- Plugin keybindings: todo-comments
---------------------------------------------------------------

-- Search all TODOs/FIXMEs/HACKs across the project.
vim.keymap.set("n", "<leader>ft", "<cmd>TodoTelescope<cr>", { desc = "Find TODOs" })
vim.keymap.set("n", "]t", function() require("todo-comments").jump_next() end, { desc = "Next TODO" })
vim.keymap.set("n", "[t", function() require("todo-comments").jump_prev() end, { desc = "Prev TODO" })

---------------------------------------------------------------
-- Plugin keybindings: session persistence
---------------------------------------------------------------

-- Restore the session for the current directory.
vim.keymap.set("n", "<leader>qs", function() require("persistence").load() end, { desc = "Restore session" })
vim.keymap.set("n", "<leader>ql", function() require("persistence").load({ last = true }) end, { desc = "Restore last session" })
vim.keymap.set("n", "<leader>qd", function() require("persistence").stop() end, { desc = "Stop session recording" })

---------------------------------------------------------------
-- Plugin keybindings: debugger (nvim-dap)
---------------------------------------------------------------

vim.keymap.set("n", "<leader>db", function() require("dap").toggle_breakpoint() end, { desc = "Toggle breakpoint" })
vim.keymap.set("n", "<leader>dc", function() require("dap").continue() end, { desc = "Debug continue" })
vim.keymap.set("n", "<leader>do", function() require("dap").step_over() end, { desc = "Debug step over" })
vim.keymap.set("n", "<leader>di", function() require("dap").step_into() end, { desc = "Debug step into" })
vim.keymap.set("n", "<leader>dO", function() require("dap").step_out() end, { desc = "Debug step out" })
vim.keymap.set("n", "<leader>dr", function() require("dap").repl.open() end, { desc = "Debug REPL" })
vim.keymap.set("n", "<leader>dt", function() require("dap-go").debug_test() end, { desc = "Debug nearest Go test" })
vim.keymap.set("n", "<leader>du", function() require("dapui").toggle() end, { desc = "Toggle debug UI" })
