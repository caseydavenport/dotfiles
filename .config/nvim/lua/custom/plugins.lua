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
    -- tpop/X plugins for git interactions within vim.
    'tpope/vim-fugitive',
    ft = 'go',
    config = function(_)
    end
  },
  {
    -- Enables GBrowse in combintation with vim-fugitive.
    'tpope/vim-rhubarb',
    ft = 'go',
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
    ft = 'lua,go'
  }
}
return plugins
