all: packages symlinks git-config vundle

############################################################
# Symlink config files into place
############################################################
.PHONY: symlinks vimrc zshrc tmux
symlinks: vimrc zshrc tmux
vimrc:
	ln -sf $(CURDIR)/.vimrc ${HOME}/.vimrc

zshrc:
	ln -sf $(CURDIR)/.zshrc ${HOME}/.zshrc

tmux:
	ln -sf $(CURDIR)/.tmux.conf ${HOME}/.tmux.conf

############################################################
# Bash profiles (not that I use bash any more)
############################################################
mac-bash-profile:
	ln -sf $(CURDIR)/osx.bash.profile ${HOME}/.profile

bash-profile:
	ln -sf $(CURDIR)/bash.profile ${HOME}/.casey.profile

############################################################
# ZSH addons here
############################################################
zsh-addons: powerlevel10k zsh-autosuggestions zsh-syntax-highlighting .fonts-installed
$(HOME)/.oh-my-zsh:
	sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

powerlevel10k: $(HOME)/.oh-my-zsh/custom/themes/powerlevel10k
$(HOME)/.oh-my-zsh/custom/themes/powerlevel10k: $(HOME)/.oh-my-zsh
	git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $@

zsh-autosuggestions:
$(HOME)/.oh-my-zsh/plugins/zsh-autosuggestions: $(HOME)/.oh-my-zsh
	git clone https://github.com/zsh-users/zsh-autosuggestions $@

zsh-syntax-highlighting:
$(HOME)/.oh-my-zsh/plugins/zsh-syntax-highlighting: $(HOME)/.oh-my-zsh
	git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${HOME}/.oh-my-zsh/plugins/zsh-syntax-highlighting

# TODO - Too lazy to script right now.
.fonts-installed:
	xdg-open https://github.com/romkatv/powerlevel10k
	touch $@

############################################################
# Configure git
############################################################
git-config:
	git config --global core.editor vim
	git config --global user.name "Casey Davenport"
	git config --global user.email "davenport.cas@gmail.com"
	git config --global color.ui true
	git config --global pager.branch false

############################################################
# Vim package manager - vundle
# After running this, launch vim and :PluginInstall
############################################################
vundle:
	mkdir -p ~/.vim/bundle
	git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim

############################################################
# Basic packages, and other minutia. For ease of remembering.
############################################################
.PHONY: packages apt docker lazy-boy
packages: apt docker lazy-boy
apt:
	sudo apt update
	sudo apt install -y \
		vim \
		build-essential \
		cmake \
		python-dev \
		python3-dev \
		zsh \
		ca-certificates \
		curl \
		gnupg \
		lsb-release \
		sl

# From here: https://docs.docker.com/engine/install/ubuntu/
docker: packages
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update && sudo apt-get install docker-ce docker-ce-cli containerd.io
	sudo usermod -aG docker $(USER)

# Too lazy to script, just open the instructions in a browser.
lazy-boy:
	xdg-open https://go.dev/doc/install
	xdg-open https://slack.com
