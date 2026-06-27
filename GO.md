# Go in Neovim

> Editor workflow for Go - the shared gopls daemon, vim-go, debugging, coverage, tests. This is distinct from `~/.claude/GO.md`, which is the Go coding-style guide. Keybindings live in [VIM.md](VIM.md); this is setup and workflow.

## LSP / gopls

The config connects to a shared gopls daemon over a unix socket at `$XDG_RUNTIME_DIR/gopls.sock` when one is running, so nvim shares a cache with other tools (e.g. Claude Code). It falls back to a per-instance gopls when the socket isn't there. Both vim-go and the LSP client use the same daemon, and gofumpt formatting is on.

## vim-go commands

The `<leader>g` group: `gi` implementations, `gr` references, `gf` fill struct, `ge` generate if-err, `gk` callers, `gn` rename, `gd`/`gD` doc / doc-in-browser, `gI` generate method stubs, `gs`/`gS` highlight / clear identifier. `:A` switches between `.go` and `_test.go`.

## Tests

vim-test runs `go test`. `<leader>tn` nearest, `<leader>tf` file, `<leader>ts` suite, `<leader>tl` last. Runs in a neovim terminal split.

## Coverage

nvim-goc overlays covered/uncovered lines. `<leader>gcr` runs and highlights, `<leader>gcc` clears.

## Debugging

nvim-dap + nvim-dap-go (delve). `<leader>db` breakpoint, `<leader>dc` continue, `<leader>dt` debug nearest test, `<leader>du` toggle the dap-ui. The `<leader>d*` keys are shared with Python.
