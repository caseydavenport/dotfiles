# Source git completion.
source /Users/casey/git-completion.bash

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

# Add GNU tar to path.
export PATH=/usr/local/opt/gnu-tar/libexec/gnubin:$PATH

# Bash alias to start go programming.
alias letsgo='cd $GOPATH/src && printf "\nChanged to: $(pwd)\n"'

export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
