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
      vim.g.go_gopls_gofumpt=1
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
      require 'plugins.configs.lspconfig'
      require 'custom.configs.lspconfig'
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
    ft = 'lua,go,js,py',
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
    ft = 'lua,go,js,py',
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
    "ramilito/kubectl.nvim",
    config = function()
      require("kubectl").setup()
    end,
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
}
return plugins
