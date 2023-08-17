-- Import the default on_attach and capabilities functions from the main lspconfig.
local on_attach = require('plugins.configs.lspconfig').on_attach
local capabilities = require('plugins.configs.lspconfig').capabilities

local lspconfig = require 'lspconfig'

-- Configure gopls language server for golang files.
lspconfig.gopls.setup{
  capabilities = capabilities,
  on_attach = on_attach,
  filetypes = {"go"},
  root_dir = lspconfig.util.root_pattern('go.mod')
}

-- Open a floating dialog.
vim.keymap.set('n', '<space>e', vim.diagnostic.open_float)
