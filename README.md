# dotfiles

Config files for zsh, tmux, neovim, and git. Catppuccin Mocha themed throughout.

## Quick start

```bash
git clone git@github.com:caseydavenport/dotfiles.git ~/dotfiles
cd ~/dotfiles
make setup
```

This is idempotent -- safe to re-run anytime. It symlinks configs into `~`, installs
zsh addons (oh-my-zsh, powerlevel10k, plugins, fzf), and installs CLI tools via
`install-terminal-bling.sh` (that part needs sudo).

## Targets

```
make setup          # Full idempotent setup
make symlinks       # Just symlink config files
make zsh-addons     # Just install zsh plugins
make terminal-bling # Just install CLI tools (needs sudo)
make neovim         # Install neovim + NvChad (not part of setup)
make packages       # Base apt packages + docker (not part of setup)
make help           # List all targets
```

## What's in the box

- **zsh** -- oh-my-zsh + powerlevel10k, kubectl/docker completions, history substring search, fzf with bat/eza previews
- **tmux** -- Powerline status bar with k8s context, sync-panes indicator, true color + undercurl
- **git** -- delta for side-by-side syntax-highlighted diffs
- **CLI tools** -- eza, bat, delta, lolcat, kubectx, kubens, k9s, stern, kubectl-tree, kubectl-neat

See [TERMINAL-BLING.md](TERMINAL-BLING.md) for the full cheatsheet.
