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
