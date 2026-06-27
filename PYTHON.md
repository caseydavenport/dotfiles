# Python in Neovim

basedpyright + ruff, venv-aware, with pytest, debugging, and an IPython REPL. Keybindings live in [VIM.md](VIM.md); this is setup and workflow.

## One-time setup

```bash
make python-tools
```

Installs `basedpyright`, `ruff`, `ipython`, and `jupytext` via pipx, plus `fd` (apt `fd-find`) for the venv picker. `make neovim` runs this too. Needs `~/.local/bin` on PATH (`pipx ensurepath`).

## Virtualenvs

basedpyright and ruff resolve imports against whatever interpreter is active, so pointing them at the right venv matters. A `.venv` in the project root and an active `$VIRTUAL_ENV` get picked up automatically. Otherwise `<leader>Pv` opens a picker (virtualenvs and conda envs); selecting one restarts the LSPs against it.

## Linting and formatting

ruff handles both. On save, imports get sorted and the buffer gets ruff-formatted - the Python equivalent of gofumpt-on-save. This runs through conform.nvim (`ruff_organize_imports` then `ruff_format`), so project config in `pyproject.toml` / `ruff.toml` is respected. basedpyright runs in `basic` type-checking mode; bump it in `custom/configs/python.lua` if you want stricter.

## Tests

vim-test runs pytest. `<leader>tn` nearest, `<leader>tf` file, `<leader>ts` suite, `<leader>tl` last. Runs in a neovim terminal split, and pytest comes from the active venv.

## Debugging

nvim-dap-python wraps debugpy. Install debugpy into the project venv (`pip install debugpy`), set a breakpoint with `<leader>db`, then `<leader>dt` to debug the nearest test or `<leader>dc` to launch. dap-ui opens automatically. The generic dap keys (`<leader>d*`) are shared with Go.

## REPL and notebooks

`<leader>Pr` opens an IPython REPL split; `<leader>Pl` / `<leader>Ps` send the current line / visual selection. `.ipynb` files open as editable text via jupytext and round-trip back to notebook format on save.

## Troubleshooting

- **LSP not attaching:** `:LspInfo` should list basedpyright and ruff. If not, check `make python-tools` ran and the binaries are on PATH.
- **Wrong imports flagged:** usually the wrong interpreter - `<leader>Pv` and pick the project venv.
- **Not formatting/sorting on save:** it's conform.nvim calling ruff (`custom/configs/python.lua` registers the LSP, `custom/plugins.lua` has the conform spec). Make sure `ruff` is on PATH; conform is lazy-loaded on the `python` filetype.
- **`<leader>Pv` missing or fd error on `.py` open:** venv-selector needs the `fd` binary. On Debian/Ubuntu it's `fdfind` (`sudo apt install fd-find`), which `make python-tools` installs; the config points venv-selector at `fdfind`.
