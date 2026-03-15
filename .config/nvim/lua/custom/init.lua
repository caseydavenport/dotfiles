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
-- Which-key group labels
---------------------------------------------------------------

-- Register after plugins load so which-key is available.
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyDone",
  callback = function()
    local ok, wk = pcall(require, "which-key")
    if ok then
      wk.add({
        -- Top-level groups with icons.
        { "<leader>a", group = "AI", icon = "󰚩" },
        { "<leader>c", group = "Copilot Chat", icon = "" },
        { "<leader>d", group = "Debug", icon = "" },
        { "<leader>f", group = "Find", icon = "" },
        { "<leader>g", group = "Go / Git", icon = "" },
        { "<leader>gc", group = "Coverage", icon = "󰈸" },
        { "<leader>h", group = "Bookmarks", icon = "󰃀" },
        { "<leader>q", group = "Sessions", icon = "󰆓" },
        { "<leader>r", group = "Review", icon = "" },
        { "<leader>x", group = "Diagnostics", icon = "" },

        -- NvChad telescope bindings with descriptions.
        { "<leader>ff", desc = "Find files" },
        { "<leader>fa", desc = "Find all files" },
        { "<leader>fw", desc = "Live grep" },
        { "<leader>fb", desc = "Find buffers" },
        { "<leader>fh", desc = "Help tags" },
        { "<leader>fo", desc = "Find recent files" },
        { "<leader>fz", desc = "Find in current buffer" },

        -- Git bindings.
        { "<leader>gs", desc = "Git status" },
        { "<leader>gcm", desc = "Git commits" },
        { "<leader>gbl", desc = "Git blame line" },
        { "<leader>gbr", desc = "Open on GitHub" },

        -- Hide remapped/unused bindings from which-key.
        { "<leader>gt", hidden = true },
        { "<leader>gb", hidden = true },
        { "<leader>cm", hidden = true },
        { "<leader>ma", hidden = true },
        { "<leader>th", hidden = true },
        { "<leader>c", hidden = true },

        -- Gitsigns bindings.
        { "<leader>p", group = "Git preview", icon = "" },
        { "<leader>ph", desc = "Preview hunk" },
        { "<leader>td", desc = "Toggle deleted lines" },

        -- LSP workspace bindings.
        { "<leader>w", group = "Workspace", icon = "" },
        { "<leader>wa", desc = "Add workspace folder" },
        { "<leader>wr", desc = "Remove workspace folder" },
        { "<leader>wl", desc = "List workspace folders" },

        -- NvChad misc bindings.
        { "<leader>e", desc = "File tree focus" },
        { "<leader>b", desc = "Toggle file tree" },
        { "<leader>ch", desc = "Keybinding cheatsheet" },
        { "<leader>n", desc = "Line numbers" },
        { "<leader>/", desc = "Toggle comment" },
      })

      -- Unbind things we don't use.
      pcall(vim.keymap.del, "n", "<leader>ma")
      pcall(vim.keymap.del, "n", "<leader>th")
      pcall(vim.keymap.del, "n", "<leader>cm")
      pcall(vim.keymap.del, "n", "<leader>gt")
      pcall(vim.keymap.del, "n", "<leader>gb")
      pcall(vim.keymap.del, "n", "<leader>c")
      pcall(vim.keymap.del, "x", "<leader>c")

    end
  end,
  once = true,
})

-- Move telescope marks/bookmarks to <leader>fk.
vim.keymap.set("n", "<leader>fk", "<cmd>Telescope marks<cr>", { desc = "Find marks" })

-- Git bindings under <leader>g.
vim.keymap.set("n", "<leader>gs", "<cmd>Telescope git_status<cr>", { desc = "Git status" })
vim.keymap.set("n", "<leader>gcm", "<cmd>Telescope git_commits<cr>", { desc = "Git commits" })
vim.keymap.set("n", "<leader>gbl", function() package.loaded.gitsigns.blame_line() end, { desc = "Git blame line" })
vim.keymap.set("n", "<leader>gbr", "<cmd>GBrowse<cr>", { desc = "Open on GitHub" })

-- Move copilot chat to <leader>ac (under AI group).
vim.keymap.set("n", "<leader>ac", "<cmd>CopilotChatToggle<cr>", { desc = "Copilot Chat" })
vim.keymap.set("x", "<leader>ac", "<cmd>CopilotChatToggle<cr>", { desc = "Copilot Chat" })

---------------------------------------------------------------
-- Claude Code floating terminal
---------------------------------------------------------------

-- Toggle Claude Code in a floating window. Reuses the same session.
local claude_buf = nil
local claude_win = nil

local function open_claude_float()
  local width = math.floor(vim.o.columns * 0.85)
  local height = math.floor(vim.o.lines * 0.85)
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
  }

  -- If we have a live buffer, just re-show it.
  if claude_buf and vim.api.nvim_buf_is_valid(claude_buf) then
    claude_win = vim.api.nvim_open_win(claude_buf, true, opts)
    vim.cmd("startinsert")
    return
  end

  -- Otherwise, create a new buffer and start claude.
  claude_buf = vim.api.nvim_create_buf(false, true)
  claude_win = vim.api.nvim_open_win(claude_buf, true, opts)
  vim.fn.termopen("claude", {
    on_exit = function()
      claude_buf = nil
      claude_win = nil
    end,
  })
  vim.cmd("startinsert")
end

local function toggle_claude()
  if claude_win and vim.api.nvim_win_is_valid(claude_win) then
    vim.api.nvim_win_close(claude_win, false)
    claude_win = nil
    return
  end
  open_claude_float()
end

vim.keymap.set("n", "<leader>ai", toggle_claude, { desc = "Toggle Claude Code" })
vim.keymap.set("t", "<C-\\><C-a>", toggle_claude, { desc = "Toggle Claude Code" })

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
