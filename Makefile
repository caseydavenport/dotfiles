# Location of the dotfiles repo.
CWD=$(shell pwd)

all: vimrc git-config 

# General dependencies.
deps:
	sudo apt install build-essential cmake python-dev python3-dev zsh

# Vim package manager - vundle
vundle:
	mkdir -p ~/.vim/bundle
	git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim

# Install .vimrc file.
vimrc:
	ln -sf ${CWD}/.vimrc ${HOME}/.vimrc

# Install .zshrc file.
zshrc:
	ln -sf ${CWD}/.zshrc ${HOME}/.zshrc

# Commands for installing various bash profiles.
# They're just aliases for copying files around.
mac-bash-profile:
	ln -sf ${CWD}/osx.bash.profile ${HOME}/.profile

bash-profile:
	ln -sf ${CWD}/bash.profile ${HOME}/.casey.profile

# zsh configuration files
zsh-config: powerlevel9k zsh-autosuggestions zsh-syntax-highlighting

powerlevel9k:
	git clone https://github.com/bhilburn/powerlevel9k.git ${HOME}/.oh-my-zsh/custom/themes/powerlevel9k

zsh-autosuggestions:
	git clone https://github.com/zsh-users/zsh-autosuggestions ${HOME}/.oh-my-zsh/plugins/zsh-autosuggestions

zsh-syntax-highlighting:
	git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${HOME}/.oh-my-zsh/plugins/zsh-syntax-highlighting


# Copy tmux configuration into place.
tmux:
	ln -sf ${CWD}/.tmux.conf ${HOME}/.tmux.conf

# Install my default git configurations.
git-config:
	git config --global core.editor vim
	git config --global user.name "Casey Davenport"
	git config --global user.email "davenport.cas@gmail.com"
	git config --global color.ui true

# Slate for OSX
slate:
	cd /Applications && curl http://www.ninjamonkeysoftware.com/slate/versions/slate-latest.tar.gz | tar -xz
