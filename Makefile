# Location of the dotfiles repo.
CWD=$(shell pwd)

all: vimrc git-config plugins
plugins: go-plugin ycm

# Install .vimrc file.
vimrc: pathogen
	 ln -sf ${CWD}/.vimrc ${HOME}/.vimrc

# Tmux config.
tmux: 
	ln -sf ${CWD}/.tmux.conf ${HOME}/.tmux.conf

# Installs pathogen plugin manager for vim.
pathogen:
	mkdir -p ~/.vim/autoload ~/.vim/bundle
	curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

# Install the vim golang plugin.
go-plugin: pathogen
	if [ ! -e ~/.vim/bundle/vim-go ]; then \
		mkdir -p ~/.vim/bundle; \
		git clone https://github.com/fatih/vim-go.git ~/.vim/bundle/vim-go; \
	fi

# Download YouCompleteMe for vim.
ycm:
	sudo apt-get -f install cmake build-essential python-dev || true
	mkdir -p ~/.vim/bundle
	if [ ! -e ~/.vim/bundle/vim-go ]; then \
		git clone git@github.com:Valloric/YouCompleteMe.git ~/.vim/bundle/YouCompleteMe; \
	fi
	cd ~/.vim/bundle/YouCompleteMe && git submodule update --init --recursive
	cd ~/.vim/bundle/YouCompleteMe && ./install.py 

# Install my default git configurations.
git-config:
	git config --global core.editor vim
	git config --global user.name "Casey Davenport"
	git config --global user.email "davenport.cas@gmail.com"
	git config --global color.ui true

# Remove YouCompleteMe.
clean-ycm:
	rm -rf ~/.vim/bundle/YouCompleteMe

# Remove vim-go.
clean-go-plugin:
	rm -rf ~/.vim/bundle/vim-go

# Remove .vimrc symlink.
clean:
	rm -f ${HOME}/.vimrc
