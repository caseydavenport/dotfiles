.PHONY: setup symlinks zshrc tmux gitconfig p10k dircolors \
       zsh-addons oh-my-zsh powerlevel10k zsh-autosuggestions \
       zsh-syntax-highlighting zsh-history-substring-search fzf \
       terminal-bling neovim nvimrc packages apt docker help bat-themes bin

############################################################
# Default target: show available targets
############################################################
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "  setup          Idempotent full setup (symlinks + zsh addons + terminal bling)"
	@echo "  symlinks       Symlink config files into ~"
	@echo "  zsh-addons     Install oh-my-zsh, plugins, p10k, fzf"
	@echo "  terminal-bling Install eza, bat, delta, lolcat, k8s tools (needs sudo)"
	@echo "  neovim         Install neovim + NvChad + config symlink"
	@echo "  packages       Install base apt packages + docker"
	@echo ""

############################################################
# Top-level setup: idempotent, safe to re-run on any machine
############################################################
setup: symlinks zsh-addons terminal-bling
	@echo ""
	@echo "Setup complete! Run 'source ~/.zshrc' to activate."

############################################################
# Symlink config files into place
############################################################
symlinks: zshrc tmux gitconfig p10k dircolors delta bat-themes bin

zshrc:
	ln -sf $(CURDIR)/.zshrc ${HOME}/.zshrc

tmux:
	ln -sf $(CURDIR)/.tmux.conf ${HOME}/.tmux.conf

gitconfig:
	ln -sf $(CURDIR)/.gitconfig ${HOME}/.gitconfig

p10k:
	ln -sf $(CURDIR)/.p10k.zsh ${HOME}/.p10k.zsh

dircolors:
	ln -sf $(CURDIR)/.dircolors ${HOME}/.dircolors

delta:
	mkdir -p ${HOME}/.config/delta
	ln -sf $(CURDIR)/.config/delta/catppuccin.gitconfig ${HOME}/.config/delta/catppuccin.gitconfig

bat-themes:
	mkdir -p ${HOME}/.config/bat/themes
	ln -sf $(CURDIR)/.config/bat/themes/"Catppuccin Mocha.tmTheme" ${HOME}/.config/bat/themes/"Catppuccin Mocha.tmTheme"
	ln -sf $(CURDIR)/.config/bat/themes/"Catppuccin Macchiato.tmTheme" ${HOME}/.config/bat/themes/"Catppuccin Macchiato.tmTheme"
	ln -sf $(CURDIR)/.config/bat/themes/"Catppuccin Frappe.tmTheme" ${HOME}/.config/bat/themes/"Catppuccin Frappe.tmTheme"
	$(shell command -v bat || command -v batcat) cache --build

bin:
	mkdir -p ${HOME}/.local/bin
	@for f in $(CURDIR)/bin/*; do \
		ln -sf $$f ${HOME}/.local/bin/$$(basename $$f); \
		echo "Linked bin: $$(basename $$f)"; \
	done

nvimrc:
	ln -sf $(CURDIR)/.config/nvim/lua/custom ${HOME}/.config/nvim/lua/custom

############################################################
# ZSH addons
############################################################
zsh-addons: oh-my-zsh powerlevel10k zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search fzf

oh-my-zsh:
	@[ -d $(HOME)/.oh-my-zsh ] || (curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o /tmp/install-oh-my-zsh.sh && sh /tmp/install-oh-my-zsh.sh)

powerlevel10k: oh-my-zsh
	@[ -d $(HOME)/.oh-my-zsh/custom/themes/powerlevel10k ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $(HOME)/.oh-my-zsh/custom/themes/powerlevel10k

zsh-autosuggestions: oh-my-zsh
	@[ -d $(HOME)/.oh-my-zsh/plugins/zsh-autosuggestions ] || git clone https://github.com/zsh-users/zsh-autosuggestions $(HOME)/.oh-my-zsh/plugins/zsh-autosuggestions

zsh-syntax-highlighting: oh-my-zsh
	@[ -d $(HOME)/.oh-my-zsh/plugins/zsh-syntax-highlighting ] || git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $(HOME)/.oh-my-zsh/plugins/zsh-syntax-highlighting

zsh-history-substring-search: oh-my-zsh
	@[ -d $(HOME)/.oh-my-zsh/custom/plugins/zsh-history-substring-search ] || git clone https://github.com/zsh-users/zsh-history-substring-search.git $(HOME)/.oh-my-zsh/custom/plugins/zsh-history-substring-search

fzf:
	@[ -d $(HOME)/.fzf ] || (git clone --depth 1 https://github.com/junegunn/fzf.git $(HOME)/.fzf && $(HOME)/.fzf/install --key-bindings --completion --no-update-rc --no-bash --no-fish)

############################################################
# Terminal bling (eza, bat, delta, lolcat, k8s tools)
############################################################
terminal-bling:
	@$(CURDIR)/install-terminal-bling.sh || echo ">> terminal-bling requires sudo — run ~/install-terminal-bling.sh manually"

############################################################
# Neovim (manual, not part of setup)
############################################################
neovim: nvimrc
	@command -v nvim >/dev/null || (wget -q https://github.com/neovim/neovim/releases/download/stable/nvim.appimage -O /tmp/nvim.appimage && chmod u+x /tmp/nvim.appimage && sudo mv /tmp/nvim.appimage /usr/local/bin/nvim)
	@[ -d $(HOME)/.config/nvim/.git ] || git clone https://github.com/NvChad/NvChad ~/.config/nvim --depth 1

############################################################
# Base packages + docker (manual, needs sudo)
############################################################
packages: apt docker

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
		lsb-release

# From here: https://docs.docker.com/engine/install/ubuntu/
docker:
	@command -v docker >/dev/null || ( \
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
		echo "deb [arch=$$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
		sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io && \
		sudo usermod -aG docker $$USER \
	)
