CWD=$(shell pwd)

all: install-vim

install-vim:
	 ln -s ${CWD}/.vimrc ${HOME}/.vimrc

clean:
	rm -f ${HOME}/.vimrc
