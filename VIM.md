# Neovim Cheatsheet

NvChad + Catppuccin Mocha + custom plugins for Go development.

## Keybindings

NvChad's leader key is `Space`. Press it and wait to see which-key groups with icons.

### Navigation

| Key | Action |
|-----|--------|
| `Enter` | Flash jump — type a char, then a label to jump |
| `Shift+Enter` | Flash treesitter select |
| `Alt+h/j/k/l` | Move between vim splits and tmux panes |
| `<leader>ha` | Add current file to harpoon |
| `<leader>hh` | Open harpoon quick menu (edit with `dd`, save with `:wq`) |
| `<leader>1-4` | Jump to harpoon file 1-4 |
| `<leader>e` | Focus file panel (nvim-tree) |
| `<leader>b` | Toggle file panel |
| `Tab` / `Shift+Tab` | Next/prev buffer |
| `<leader>x` | Close current buffer |

### Search (Telescope)

| Key | Action |
|-----|--------|
| `<leader>ff` | Find files |
| `<leader>fw` | Live grep (word search) |
| `<leader>fg` | Live grep with ripgrep args (e.g., append `-t go`) |
| `<leader>fb` | Find buffers |
| `<leader>fh` | Help tags |
| `<leader>fa` | Find all files (including hidden/ignored) |
| `<leader>fo` | Find recent files |
| `<leader>fz` | Fuzzy find in current buffer |
| `<leader>fk` | Find marks/bookmarks |
| `<leader>ft` | Find all TODOs/FIXMEs/HACKs in project |

### Go development

| Key | Action |
|-----|--------|
| `<leader>ds` | Go to definition in horizontal split |
| `<leader>dv` | Go to definition in vertical split |
| `<leader>gi` | Go to implementations |
| `<leader>T` | Run nearest test |
| `:A` | Switch between `.go` and `_test.go` |
| `gJ` | Join struct fields to one line (splitjoin) |
| `gS` | Split struct fields to multiple lines (splitjoin) |
| `<leader>gcr` | Run Go test coverage and highlight lines |
| `<leader>gcc` | Clear coverage highlights |

### Debugging (nvim-dap)

| Key | Action |
|-----|--------|
| `<leader>db` | Toggle breakpoint |
| `<leader>dc` | Continue (start/resume debugging) |
| `<leader>do` | Step over |
| `<leader>di` | Step into |
| `<leader>dO` | Step out |
| `<leader>dr` | Open debug REPL |
| `<leader>dt` | Debug nearest Go test |
| `<leader>du` | Toggle debug UI panel |

### Diagnostics

| Key | Action |
|-----|--------|
| `<leader>xx` | Toggle all diagnostics panel (Trouble, right side) |
| `<leader>xd` | Toggle buffer-only diagnostics (Trouble) |
| `<leader>xq` | Toggle quickfix list (Trouble) |
| `[d` / `]d` | Previous/next diagnostic (built-in) |
| `]t` / `[t` | Next/prev TODO comment |

### Git

| Key | Action |
|-----|--------|
| `<leader>gs` | Git status (telescope) |
| `<leader>gcm` | Git commits (telescope) |
| `<leader>gbl` | Blame current line |
| `<leader>gbr` | Open current file on GitHub |
| `<leader>ph` | Preview git hunk |
| `<leader>td` | Toggle showing deleted lines |
| `[c` / `]c` | Previous/next git hunk |

### Octo (PR review)

| Key | Action |
|-----|--------|
| `:Octo pr list` | List PRs for review |
| `<leader>ca` | Add review comment |
| `<leader>cs` | Add review suggestion |
| `<leader>rs` | Submit review |
| `<leader>rd` | Discard review |
| `]q` / `[q` | Next/prev file in review |
| `<leader>q` | Close review |

### Sessions

| Key | Action |
|-----|--------|
| `<leader>qs` | Restore session for current directory |
| `<leader>ql` | Restore last session |
| `<leader>qd` | Stop session recording |

### AI

| Key | Action |
|-----|--------|
| `<leader>ai` | Toggle Claude Code floating terminal (resumeable) |
| `Ctrl+\ Ctrl+a` | Hide Claude float from terminal mode |
| `<leader>ac` | Toggle Copilot Chat |
| `Alt+p` | Accept Copilot suggestion (insert mode) |

### Terminal

| Key | Action |
|-----|--------|
| `Alt+t` | Toggle horizontal terminal |
| `Alt+v` | Toggle vertical terminal |

### Misc

| Key | Action |
|-----|--------|
| `<leader>ch` | NvChad keybinding cheatsheet |
| `<leader>n` | Toggle line numbers |
| `<leader>/` | Toggle comment |
| `:MarkdownPreview` | Live preview of markdown files |

## Which-key groups

Press `<leader>` to see these organized groups:

- 󰚩 **AI** — Claude Code, Copilot Chat
- 󰃀 **Bookmarks** — Harpoon file bookmarks
-  **Debug** — Breakpoints, stepping, REPL
-  **Diagnostics** — Trouble panel, quickfix
-  **Find** — All telescope search bindings
-  **Go / Git** — Go tools, coverage, git status/commits/blame
-  **Git preview** — Hunk preview, deleted lines
- 󰆓 **Sessions** — Save/restore project sessions
-  **Review** — Octo PR review
-  **Workspace** — LSP workspace folders

## Plugins

- **vim-go** -- Go highlighting, formatting (gofumpt), gopls integration
- **nvim-lspconfig** -- LSP support (gopls enabled)
- **nvim-dap + nvim-dap-go + nvim-dap-ui** -- Debugger with breakpoints, stepping, variable inspection
- **flash.nvim** -- Jump to any visible character in 2 keystrokes
- **vim-tmux-navigator** -- Seamless Alt+h/j/k/l across vim splits and tmux panes
- **copilot + CopilotChat** -- AI completions and chat
- **octo.nvim** -- GitHub PR review inside neovim (unified diff mode)
- **vim-fugitive + vim-rhubarb** -- Git commands and GitHub integration
- **telescope + fzf-native + live-grep-args** -- Fuzzy finding with fast native sorter
- **trouble.nvim** -- Diagnostics panel (opens on the right)
- **todo-comments.nvim** -- Highlight and search TODO/FIXME/HACK comments
- **harpoon** -- File bookmarks for quick jumping
- **persistence.nvim** -- Auto-save/restore sessions per project directory
- **neoscroll** -- Smooth scrolling
- **nvim-goc** -- Go test coverage overlay
- **splitjoin** -- Split/join struct fields
- **vim-delve** -- Go debugger (legacy, nvim-dap preferred)
- **vim-test** -- Run tests from vim
- **nvim-tree** -- File tree (adaptive size)
- **markdown-preview** -- Live markdown preview in browser
- **LuaSnip** -- Custom snippets

## Editor settings

- Line ruler at column 160
- No swap files
- Restores cursor position on file reopen
- Trims trailing whitespace on save
- Inline diagnostic text (virtual text, not virtual lines)
- Smart autopairs (won't double-insert closing brackets)
- Catppuccin Mocha color scheme
