# Source git completion.
source /Users/casey/git-completion.bash

# Try to source docker environment.
eval $(docker-machine env dev)

# The next line updates PATH for the Google Cloud SDK.
source '/Users/casey/google-cloud-sdk/path.bash.inc'

# The next line enables shell command completion for gcloud.
source '/Users/casey/google-cloud-sdk/completion.bash.inc'

# Set GOPATH.
export GOPATH=/Users/casey/repos

# Add go binaries to path.
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

# Add GNU tar to path.
export PATH=/usr/local/opt/gnu-tar/libexec/gnubin:$PATH
