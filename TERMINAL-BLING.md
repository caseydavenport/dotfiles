# Terminal Bling Cheatsheet

Run `~/install-terminal-bling.sh` and `source ~/.zshrc`, then try these out.

## Setup

- `make setup` — idempotent one-shot: symlinks + zsh addons + terminal bling installs
- `~/install-terminal-bling.sh` — installs eza, bat, delta, lolcat, kubectx, kubens, k9s, stern, krew plugins

## eza (replaces ls)

- `ls` — file listing with icons and directories grouped first
- `ll` — detailed listing with git status per file
- `tree` — recursive tree view with icons

## bat (replaces cat)

- `cat somefile.go` — syntax-highlighted output automatically
- `bat --style=full somefile.go` — adds line numbers, git changes, header

## delta (replaces git diff)

- `git diff` — unified diffs with syntax highlighting and line numbers
- `git log -p` — commit history with pretty diffs
- `git show HEAD` — all go through delta automatically

## lolcat

- `echo "hello" | lolcat` — rainbow text
- `ls | lolcat` — rainbow anything

## fzf (fuzzy finder)

- `Ctrl+R` — fuzzy history search with preview (use arrow keys to cycle matches)
- `Ctrl+T` — fuzzy file finder with bat syntax-highlighted preview
- `Alt+C` — fuzzy directory picker with eza tree preview
- Catppuccin Mocha colors applied to all fzf popups

## zoxide (smart cd)

- `z calico` — jump to most-visited directory matching "calico"
- `z proj cal` — matches on multiple words
- `zi` — interactive fuzzy picker
- Learns as you `cd` around, gets smarter over time

## history substring search

- Type part of a previous command (e.g., `kubectl get`), then press **Up/Down arrow** to cycle through matching history entries

## kubectl completions

- `k get po<TAB>` — completes `pods`
- `k get pods -n <TAB>` — completes namespace names
- `k describe <TAB>` — completes resource types, then resource names

## docker completions

- `docker run <TAB>`, `docker compose <TAB>` — full subcommand and flag completion

## Kubernetes workflow tools

- `kubectx` — fuzzy switch between k8s contexts (uses fzf)
- `kubens` — fuzzy switch between namespaces (uses fzf)
- `k9s` — full TUI cluster dashboard (like htop for Kubernetes)
- `stern calico-node -n kube-system` — multi-pod colored log tailing
- `kubectl tree deployment/myapp` — show resource ownership hierarchy
- `kubectl neat get pod mypod -o yaml` — clean yaml without managedFields junk

## Catppuccin Mocha theme

Consistent palette across all tools:

| Role | Color | Where |
|------|-------|-------|
| Primary accent | Lavender (183) | tmux active, p10k dir, directories in ls |
| Secondary accent | Sky (117) | tmux time, p10k k8s ctx, symlinks, source files |
| Success | Green (114) | p10k clean git, executables |
| Warning | Peach (209) | tmux sync, p10k modified git, images/video |
| Error | Pink (204) | p10k errors, orphan symlinks |
| Background | Surface1 (238) | tmux/p10k segment bg |
| Text | Text (189) | tmux/p10k main text, markdown files |
| Dimmed | Overlay0 (245) | log/tmp/cache files |

## tmux enhancements

- Powerline-style separators between status bar segments
- K8s context + namespace shown in status bar right side
- `SYNC` badge (peach) appears when pane sync is on (`prefix+e` on, `prefix+E` off)
- Auto-renumber windows when one is closed
- Fast escape time (10ms) for snappy vim
- True color (24-bit) and undercurl support
- Focus events for vim autoread
- `Alt+h/j/k/l` — seamless pane navigation across vim and tmux (vim-tmux-navigator)
- `prefix + H/J/K/L` — resize panes by 5 cells
- `prefix + Ctrl+arrow` — resize panes by 1 cell
- Transient prompt (p10k) — old prompts collapse, reappears on `cd`
