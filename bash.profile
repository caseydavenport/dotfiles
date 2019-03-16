# Source git completion.
source '/home/casey/dotfiles/git-completion.bash'

# Makefile auto-completionm magic.
complete -W "`test -e Makefile && grep -oE '^[a-zA-Z0-9_-]+:([^=]|$)' Makefile | sed 's/[^a-zA-Z0-9_-]*$//'`" make

# The next line updates PATH for the Google Cloud SDK.
source '/home/casey/google-cloud-sdk/path.bash.inc'

# The next line enables shell command completion for gcloud.
source '/home/casey/google-cloud-sdk/completion.bash.inc'

# Set GOPATH.
export GOPATH=/home/casey/repos/gopath

# Add go binaries to path.
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
export GOBIN=$GOPATH/bin

# Add GNU tar to path.
export PATH=/usr/local/opt/gnu-tar/libexec/gnubin:$PATH

# Add gems to path
export PATH=$PATH:/home/casey/.gem/ruby/2.4.0/bin

# Set vim as my editor.
export EDITOR=vim

# Bash alias to start go programming.
alias letsgo='cd $GOPATH/src && printf "\nChanged to: $(pwd)\n"'

# Shortcuts for kubectl
alias k='kubectl'
alias kn='kubectl -n kube-system'
alias kgc='set -x; kubectl get pods -n kube-system -l k8s-app=calico-node; set +x'
alias kgt='set -x; kubectl get pods -n kube-system -l k8s-app=calico-typha; set +x'

# Hub alias as git
if [ -f /usr/local/hub/etc/hub.bash_completion.sh ]; then
	. /usr/local/hub/etc/hub.bash_completion.sh
fi
export PATH=$PATH:/usr/local/hub/bin
eval "$(hub alias -s)"

# Alias watch so that it works with other aliased commands.
alias watch='watch '

# Alias for faster squash commits.
alias squashon='git commit -a -m f && git rebase -i'

export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting
export PATH="$PATH:/home/casey/repos/k8sh" # Add k8sh to PATH for easy access.

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

alias jenky='gcloud compute ssh jenkins --project unique-caldron-775 --zone us-central1-f --ssh-flag="-Llocalhost:8080:localhost:8080"'

# Set up bash prompt.
export PS1="[\u@\h \W]$ "
