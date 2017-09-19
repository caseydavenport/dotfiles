# Source git completion.
source '/Users/casey/dotfiles/git-completion.bash'

# Makefile auto-completionm magic.
complete -W "`test -e Makefile && grep -oE '^[a-zA-Z0-9_-]+:([^=]|$)' Makefile | sed 's/[^a-zA-Z0-9_-]*$//'`" make

# The next line updates PATH for the Google Cloud SDK.
source '/Users/casey/google-cloud-sdk/path.bash.inc'

# The next line enables shell command completion for gcloud.
source '/Users/casey/google-cloud-sdk/completion.bash.inc'

# Set GOPATH.
export GOPATH=/Users/casey/repos/gopath

# Add go binaries to path.
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
export GOBIN=$GOPATH/bin

# Add GNU tar to path.
export PATH=/usr/local/opt/gnu-tar/libexec/gnubin:$PATH

# Set vim as my editor.
export EDITOR=vim

# Bash alias to start go programming.
alias letsgo='cd $GOPATH/src && printf "\nChanged to: $(pwd)\n"'

# Shortcuts for kubectl
alias k='kubectl'
alias kgc='set -x; kubectl get pods -n kube-system -l k8s-app=calico-node; set +x'
alias kgt='set -x; kubectl get pods -n kube-system -l k8s-app=calico-typha; set +x'

# Alias watch so that it works with other aliased commands.
alias watch='watch '

export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting
export PATH="$PATH:/Users/casey/repos/k8sh" # Add k8sh to PATH for easy access.

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
