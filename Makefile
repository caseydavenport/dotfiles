# Location of the dotfiles repo.
CWD=$(shell pwd)

all: vimrc git-config plugins
plugins: go-plugin ycm

# General dependencies.
deps:
	sudo apt-get install build-essential cmake python-dev python3-dev

# Tools for Go development.
golang: go-plugin tagbar go-explorer

# Vim package manager - vundle
vundle:
	mkdir -p ~/.vim/bundle
	git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim

# Install .vimrc file.
vimrc:
	ln -sf ${CWD}/.vimrc ${HOME}/.vimrc

# Commands for installing various bash profiles.
# They're just aliases for copying files around.
mac-bash-profile:
	ln -sf ${CWD}/osx.bash.profile ${HOME}/.profile

bash-profile:
	ln -sf ${CWD}/bash.profile ${HOME}/.casey.profile

vim-plug:
	curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Copy tmux configuration into place.
tmux:
	ln -sf ${CWD}/.tmux.conf ${HOME}/.tmux.conf

go-explorer:
	mkdir -p ~/.vim/bundle;
	go get github.com/garyburd/go-explorer/src/getool
	if [ ! -e ~/.vim/bundle/go-explorer ]; then \
		mkdir -p ~/.vim/bundle; \
		git clone https://github.com/garyburd/go-explorer.git ~/.vim/bundle/go-explorer; \
	fi

# Install my default git configurations.
git-config:
	git config --global core.editor vim
	git config --global user.name "Casey Davenport"
	git config --global user.email "davenport.cas@gmail.com"
	git config --global color.ui true

# Slate for OSX
slate:
	cd /Applications && curl http://www.ninjamonkeysoftware.com/slate/versions/slate-latest.tar.gz | tar -xz
