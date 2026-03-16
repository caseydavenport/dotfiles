# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH
[[ -z "$TMUX" ]] && export TERM="xterm-256color"

# Path to your oh-my-zsh installation.
export ZSH=/home/casey/.oh-my-zsh

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to load
# Setting this variable when ZSH_THEME=random
# cause zsh load theme from this variable instead of
# looking in ~/.oh-my-zsh/themes/
# An empty array have no effect
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git
  kubectl
  docker
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-history-substring-search
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
#
#
# alias to start go programming.
alias letsgo='cd $GOPATH/src && printf "\nChanged to: $(pwd)\n"'
export GOPATH=/home/casey/repos/gopath
export GOPRIVATE=github.com/tigera/*

# use nvim
alias vim=nvim
export EDITOR=nvim

# Alias watch so that it works with other aliased commands.
alias watch='watch '

alias k='kubectl'
alias kn='kubectl -n kube-system'
alias kgc='echo "+ kubectl get pods -n kube-system -l k8s-app=calico-node"; kubectl get pods -n kube-system -l k8s-app=calico-node'
alias kgt='echo "+ kubectl get pods -n kube-system -l k8s-app=calico-typha"; kubectl get pods -n kube-system -l k8s-app=calico-typha'
alias kl='kubectl logs -f'
alias kex='kubectl exec -it'
alias kaf='kubectl apply -f'

# Use kubecolor for colorized kubectl output if available.
command -v kubecolor &>/dev/null && alias kubectl='kubecolor' && alias k='kubecolor'


# Add local bin to path
export PATH=~/.local/bin:$PATH
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:/usr/local/google-cloud-sdk/bin
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:$HOME/.krew/bin


setopt auto_cd
cdpath=($HOME/repos $GOPATH $GOPATH/src/github.com/ $GOPATH/src/github.com/tigera $GOPATH/src/k8s.io)

# Source github token for hub commands.
[ -f ~/.github_token ] && source ~/.github_token
[ -f ~/.npm_token ] && source ~/.npm_token
[ -f ~/.cherry_pick_config ] && source ~/.cherry_pick_config

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# fzf: Catppuccin Mocha colors + preview enhancements
export FZF_DEFAULT_OPTS=" \
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
  --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
  --height=40% --layout=reverse --border=rounded"

# Ctrl+T: file finder with bat preview
export FZF_CTRL_T_OPTS="--preview 'batcat --color=always --style=numbers --line-range=:200 {} 2>/dev/null || head -200 {}'"

# Alt+C: cd into directory with eza tree preview
export FZF_ALT_C_OPTS="--preview 'eza --tree --icons --level=2 --color=always {} 2>/dev/null || ls -la {}'"

# Ctrl+R: history search with full command preview
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window=up:3:wrap"

# Auto-suggestion configuration.
bindkey '^k' autosuggest-accept

# History substring search - type partial command, then arrow up/down to match
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

# kube-ps1
# source $ZSH_CUSTOM/plugins/kube-ps1/kube-ps1.sh
# PROMPT='$(kube_ps1)'$PROMPT

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/casey/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/home/casey/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/casey/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/home/casey/Downloads/google-cloud-sdk/completion.zsh.inc'; fi

if [ -f '/home/linuxbrew/.linuxbrew/bin/brew' ]; then eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"; fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true

# Catppuccin Mocha dircolors (ls/eza file colors)
[ -f ~/.dircolors ] && eval "$(dircolors -b ~/.dircolors)"

# Modern CLI tool aliases
command -v batcat &>/dev/null && alias bat='batcat'  # Debian/Ubuntu names it batcat
command -v bat &>/dev/null && alias cat='bat --paging=never --style=plain'
command -v eza &>/dev/null && alias ls='eza --icons --group-directories-first' && alias ll='eza -la --icons --group-directories-first --git' && alias tree='eza --tree --icons'

# zoxide: smarter cd that learns your most-used directories.
# Use "z <partial>" to jump, "zi" for interactive fuzzy selection.
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# If there is a local env file, source it.
[ -f .casey.customenv ] && source .casey.customenv
