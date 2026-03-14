############################################################
# Top-level setup: idempotent, safe to re-run on any machine
############################################################
.PHONY: setup
setup: symlinks zsh-addons terminal-bling
	@echo ""
	@echo "Setup complete! Run 'source ~/.zshrc' to activate."

all: packages symlinks git-config

neovim: install-neovim install-nvchad nvimrc

############################################################
# Symlink config files into place
############################################################
.PHONY: symlinks zshrc tmux claude gitconfig p10k dircolors
symlinks: zshrc tmux claude gitconfig p10k dircolors

zshrc:
	ln -sf $(CURDIR)/.zshrc ${HOME}/.zshrc

tmux:
	ln -sf $(CURDIR)/.tmux.conf ${HOME}/.tmux.conf

claude:
	mkdir -p ${HOME}/.claude/skills
	ln -sf $(CURDIR)/CLAUDE.md ${HOME}/.claude/CLAUDE.md
	@for skill in $(CURDIR)/skills/*/; do \
		name=$$(basename $$skill); \
		ln -sfn $$skill ${HOME}/.claude/skills/$$name; \
		echo "Linked skill: $$name"; \
	done

gitconfig:
	ln -sf $(CURDIR)/.gitconfig ${HOME}/.gitconfig

p10k:
	ln -sf $(CURDIR)/.p10k.zsh ${HOME}/.p10k.zsh

dircolors:
	ln -sf $(CURDIR)/.dircolors ${HOME}/.dircolors

nvimrc: 
	ln -sf $(CURDIR)/.config/nvim/lua/custom ${HOME}/.config/nvim/lua/custom

############################################################
# Install neovim
############################################################
install-neovim:
	wget https://github.com/neovim/neovim/releases/download/stable/nvim.appimage
	chmod u+x nvim.appimage
	mv nvim.appimage /usr/local/bin/nvim

# Configure via this video: https://www.youtube.com/watch?v=Mtgo-nP_r8Y
install-nvchad:
	git clone https://github.com/NvChad/NvChad ~/.config/nvim --depth 1

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
zsh-addons: powerlevel10k zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search fzf .fonts-installed
$(HOME)/.oh-my-zsh:
	curl -L https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o /tmp/install-oh-my-zsh.sh && chmod +x /tmp/install-oh-my-zsh.sh && /tmp/install-oh-my-zsh.sh

powerlevel10k:
	@[ -d $(HOME)/.oh-my-zsh/custom/themes/powerlevel10k ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $(HOME)/.oh-my-zsh/custom/themes/powerlevel10k

zsh-autosuggestions:
	@[ -d $(HOME)/.oh-my-zsh/plugins/zsh-autosuggestions ] || git clone https://github.com/zsh-users/zsh-autosuggestions $(HOME)/.oh-my-zsh/plugins/zsh-autosuggestions

zsh-syntax-highlighting:
	@[ -d $(HOME)/.oh-my-zsh/plugins/zsh-syntax-highlighting ] || git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $(HOME)/.oh-my-zsh/plugins/zsh-syntax-highlighting

zsh-history-substring-search:
	@[ -d $(HOME)/.oh-my-zsh/custom/plugins/zsh-history-substring-search ] || git clone https://github.com/zsh-users/zsh-history-substring-search.git $(HOME)/.oh-my-zsh/custom/plugins/zsh-history-substring-search

fzf:
	@[ -d $(HOME)/.fzf ] || (git clone --depth 1 https://github.com/junegunn/fzf.git $(HOME)/.fzf && $(HOME)/.fzf/install --key-bindings --completion --no-update-rc --no-bash --no-fish)

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
# Terminal bling (eza, bat, delta, lolcat)
############################################################
.PHONY: terminal-bling
terminal-bling:
	@$(CURDIR)/install-terminal-bling.sh || echo ">> terminal-bling requires sudo — run ~/install-terminal-bling.sh manually"

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
	sudo usermod -aG docker $$USER

# Too lazy to script, just open the instructions in a browser.
lazy-boy:
	xdg-open https://go.dev/doc/install
	xdg-open https://slack.com
