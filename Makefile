# Location of the dotfiles repo.
CWD=$(shell pwd)

all: vimrc 
plugins: go-plugin ycm

# Install .vimrc file.
vimrc:
	 ln -s ${CWD}/.vimrc ${HOME}/.vimrc

# Install the vim golang plugin.
go-plugin:
	mkdir -p ~/.vim/bundle
	git clone https://github.com/fatih/vim-go.git ~/.vim/bundle/vim-go

# Download YouCompleteMe for vim.
ycm:
	mkdir -p ~/.vim/bundle
	git clone git@github.com:Valloric/YouCompleteMe.git ~/.vim/bundle/YouCompleteMe

clean:
	rm -f ${HOME}/.vimrc
