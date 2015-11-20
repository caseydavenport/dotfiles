# Location of the dotfiles repo.
CWD=$(shell pwd)

all: vimrc 
plugins: go-plugin ycm

# Install .vimrc file.
vimrc: pathogen
	 ln -s ${CWD}/.vimrc ${HOME}/.vimrc

pathogen:
	mkdir -p ~/.vim/autoload ~/.vim/bundle
	curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

# Install the vim golang plugin.
go-plugin: pathogen
	mkdir -p ~/.vim/bundle
	git clone https://github.com/fatih/vim-go.git ~/.vim/bundle/vim-go

# Download YouCompleteMe for vim.
ycm:
	sudo apt-get install cmake build-essential python-dev
	mkdir -p ~/.vim/bundle
	git clone git@github.com:Valloric/YouCompleteMe.git ~/.vim/bundle/YouCompleteMe

clean:
	rm -f ${HOME}/.vimrc
