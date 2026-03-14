local plugins = {
  {
    -- vim-go installation and configuraiton.
    -- Configure vim-go for highlighting and formatting on save.
    'fatih/vim-go',
    ft = 'go',
    config = function(_)
      vim.g.go_gopls_gofumpt = 1
      vim.g.go_highlight_functions = 1
      vim.g.go_highlight_methods = 1
      vim.g.go_highlight_fields = 1
      vim.g.go_highlight_types = 1
      vim.g.go_highlight_operators = 1
      vim.g.go_highlight_build_constraints = 1
      vim.g.go_def_mode = 'gopls'
      vim.g.go_info_mode = 'gopls'
    end
  },
  {
    -- splitjoin allows easy splitting / joining of structs across multiple lines.
    'AndrewRadev/splitjoin.vim',
    ft = '*',
    config = function(_)
    end
  },
  {
    -- tpop/X plugins for git interactions within vim.
    'tpope/vim-fugitive',
    ft = '*',
    config = function(_)
    end
  },
  {
    -- Enables GBrowse in combintation with vim-fugitive.
    'tpope/vim-rhubarb',
    ft = '*',
    config = function(_)
    end
  },
  {
    -- Enable language server support in NeoVim.
    'neovim/nvim-lspconfig',
    config = function(_)
    end
  },
  {
    -- Configure custom snippets.
    'L3MON4D3/LuaSnip',
    config = function(_)
      require 'custom.configs.snippets'
    end
  },
  {
    -- Install copilot.
    "github/copilot.vim",
    ft = '*',
    config = function(_)
      vim.g.copilot_no_tab_map = true
      vim.g.copilot_assume_mapped = true
      vim.api.nvim_set_keymap("i", "<A-p>", 'copilot#Accept("<CR>")', { silent = true, expr = true })
      vim.g.copilot_filetypes = {
        ["*"] = true,
        ["javascript"] = true,
        ["typescript"] = true,
        ["lua"] = true,
        ["rust"] = true,
        ["c"] = true,
        ["c#"] = true,
        ["c++"] = true,
        ["go"] = true,
        ["python"] = true,
      }
    end
  },
  {
    -- https://github.com/CopilotC-Nvim/CopilotChat.nvim
    "CopilotC-Nvim/CopilotChat.nvim",
    ft = '*',
    dependencies = {
      { "github/copilot.vim" }, -- or zbirenbaum/copilot.lua
      { "nvim-lua/plenary.nvim", branch = "master" }, -- for curl, log and async functions
    },
    build = "make tiktoken",
    opts = {
      -- See Configuration section for options
    },
    -- See Commands section for default commands if you want to lazy load on them
  },
  {
    "sebdah/vim-delve",
    ft = 'go',
    config = function(_)
    end
  },
  {
    "vim-test/vim-test",
    ft = 'go',
    config = function(_)
    end
  },
  {
      "iamcco/markdown-preview.nvim",
      cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
      ft = { "markdown" },
      build = ":call mkdp#util#install()",
  },
  {
    -- Configure nvim-tree.
    "nvim-tree/nvim-tree.lua",
    opts = {
      view = { adaptive_size = true },
    },
  },
  {
    -- GitHub PR review inside neovim.
    "caseydavenport/octo.nvim",
    branch = "casey-unified-diff",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    cmd = "Octo",
    config = function()
      require("octo").setup({
        suppress_missing_scope = {
          projects_v2 = true,
        },
        reviews = {
          diff_mode = "unified",  -- "unified" for single-pane, "split" for side-by-side
        },
        mappings = {
          review_diff = {
            add_review_comment = { lhs = "<leader>ca", desc = "add comment", mode = { "n", "x" } },
            add_review_suggestion = { lhs = "<leader>cs", desc = "add suggestion", mode = { "n", "x" } },
            submit_review = { lhs = "<leader>rs", desc = "submit review" },
            discard_review = { lhs = "<leader>rd", desc = "discard review" },
            next_thread = { lhs = "]t", desc = "next thread" },
            prev_thread = { lhs = "[t", desc = "prev thread" },
            select_next_entry = { lhs = "]q", desc = "next file" },
            select_prev_entry = { lhs = "[q", desc = "prev file" },
            focus_files = { lhs = "<leader>e", desc = "focus file panel" },
            toggle_files = { lhs = "<leader>b", desc = "toggle file panel" },
            close_review_tab = { lhs = "<leader>q", desc = "close review" },
          },
        },
      })
    end,
  },
  ---------------------------------------------------------------
  -- Visual polish
  ---------------------------------------------------------------
  {
    -- Smooth scrolling.
    "karb94/neoscroll.nvim",
    event = "VeryLazy",
    config = function()
      require("neoscroll").setup({
        mappings = { '<C-u>', '<C-d>', '<C-b>', '<C-f>', 'zt', 'zz', 'zb' },
        hide_cursor = true,
        stop_eof = true,
        respect_scrolloff = false,
        cursor_scrolls_alone = true,
      })
    end,
  },
  ---------------------------------------------------------------
  -- Telescope extensions
  ---------------------------------------------------------------
  {
    -- Native fzf sorter for telescope (much faster fuzzy matching).
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
    config = function()
      require("telescope").load_extension("fzf")
    end,
  },
  {
    -- Pass ripgrep flags interactively in live grep.
    "nvim-telescope/telescope-live-grep-args.nvim",
    config = function()
      require("telescope").load_extension("live_grep_args")
    end,
  },
  ---------------------------------------------------------------
  -- Diagnostics
  ---------------------------------------------------------------
  {
    -- Pretty diagnostics list panel.
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = "Trouble",
    config = function()
      require("trouble").setup({
        auto_preview = false,
        win = {
          type = "split",
          position = "right",
          size = 0.3,
        },
        -- Don't override built-in diagnostic virtual text.
        modes = {
          diagnostics = {
            auto_open = false,
            auto_close = false,
          },
        },
      })
    end,
  },
  ---------------------------------------------------------------
  -- Navigation
  ---------------------------------------------------------------
  {
    -- Bookmark and jump between files you're actively working on.
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("harpoon"):setup()
    end,
  },
  ---------------------------------------------------------------
  -- Go test coverage overlay
  ---------------------------------------------------------------
  {
    -- Show covered/uncovered lines after running go test.
    "rafaelsq/nvim-goc.lua",
    ft = "go",
    config = function()
      require("nvim-goc").setup()
    end,
  },
  ---------------------------------------------------------------
  -- TODO/FIXME/HACK highlighting and search
  ---------------------------------------------------------------
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = "VeryLazy",
    config = function()
      require("todo-comments").setup()
    end,
  },
  ---------------------------------------------------------------
  -- Session persistence (auto-save/restore per project)
  ---------------------------------------------------------------
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    config = function()
      require("persistence").setup({
        dir = vim.fn.stdpath("state") .. "/sessions/",
      })
    end,
  },
  ---------------------------------------------------------------
  -- Debug adapter (nvim-dap + Go support)
  ---------------------------------------------------------------
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      -- Go debug adapter using delve.
      {
        "leoluz/nvim-dap-go",
        config = function()
          require("dap-go").setup()
        end,
      },
      -- UI for dap: variable inspection, breakpoints, call stack.
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
        config = function()
          local dap, dapui = require("dap"), require("dapui")
          dapui.setup()
          -- Auto-open/close the UI when debugging starts/stops.
          dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
          dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
          dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end
        end,
      },
    },
  },
}
return plugins
