---------------------------------------------------------------
-- Python language servers
--
-- basedpyright: types, hover, go-to-def, references, rename.
-- ruff:         lint diagnostics, code actions, formatting.
-- ruff owns lint+format; basedpyright owns hover/types so they
-- don't fight over the same capabilities.
---------------------------------------------------------------

-- basedpyright: type-check only, defer lint/format to ruff.
vim.lsp.config("basedpyright", {
  cmd = { "basedpyright-langserver", "--stdio" },
  filetypes = { "python" },
  settings = {
    basedpyright = {
      analysis = {
        typeCheckingMode = "basic",
        diagnosticMode = "openFilesOnly",
        autoImportCompletions = true,
      },
    },
  },
})

-- ruff: disable hover so basedpyright is the single hover source.
vim.lsp.config("ruff", {
  cmd = { "ruff", "server" },
  filetypes = { "python" },
  on_attach = function(client, _)
    client.server_capabilities.hoverProvider = false
  end,
})

vim.lsp.enable({ "basedpyright", "ruff" })

---------------------------------------------------------------
-- Format + organize imports on save
--
-- Driven by conform.nvim (stevearc/conform.nvim) configured in
-- plugins.lua with formatters_by_ft.python = { "ruff_organize_imports",
-- "ruff_format" } and format_on_save. conform runs both steps
-- synchronously before the buffer hits disk.
--
-- The native vim.lsp organizeImports path was attempted first but
-- did not reorder imports in headless verification on nvim 0.11;
-- conform is the reliable fallback.
---------------------------------------------------------------
