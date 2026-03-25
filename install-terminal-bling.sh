#!/bin/bash
set -euo pipefail

echo "=== Installing terminal bling ==="

echo ">> Updating apt..."
sudo apt-get update -qq

echo ">> Installing lolcat..."
sudo apt-get install -y lolcat

echo ">> Installing bat (0.24.0 to match delta)..."
wget -q https://github.com/sharkdp/bat/releases/download/v0.24.0/bat_0.24.0_amd64.deb -O /tmp/bat.deb
sudo dpkg -i /tmp/bat.deb

echo ">> Installing eza..."
sudo mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
sudo apt-get update -qq
sudo apt-get install -y eza

echo ">> Installing delta..."
wget -q https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_amd64.deb -O /tmp/delta.deb
sudo dpkg -i /tmp/delta.deb

echo ">> Installing kubectx + kubens..."
if ! command -v kubectx &>/dev/null; then
    sudo apt-get install -y kubectx 2>/dev/null || {
        wget -q https://github.com/ahmetb/kubectx/releases/download/v0.9.5/kubectx_v0.9.5_linux_x86_64.tar.gz -O /tmp/kubectx.tar.gz
        sudo tar -xzf /tmp/kubectx.tar.gz -C /usr/local/bin kubectx
        wget -q https://github.com/ahmetb/kubectx/releases/download/v0.9.5/kubens_v0.9.5_linux_x86_64.tar.gz -O /tmp/kubens.tar.gz
        sudo tar -xzf /tmp/kubens.tar.gz -C /usr/local/bin kubens
    }
fi

echo ">> Installing k9s..."
if ! command -v k9s &>/dev/null; then
    wget -q https://github.com/derailed/k9s/releases/download/v0.32.7/k9s_Linux_amd64.tar.gz -O /tmp/k9s.tar.gz
    sudo tar -xzf /tmp/k9s.tar.gz -C /usr/local/bin k9s
fi

echo ">> Installing stern..."
if ! command -v stern &>/dev/null; then
    wget -q https://github.com/stern/stern/releases/download/v1.31.0/stern_1.31.0_linux_amd64.tar.gz -O /tmp/stern.tar.gz
    sudo tar -xzf /tmp/stern.tar.gz -C /usr/local/bin stern
fi

echo ">> Installing kubecolor..."
if ! command -v kubecolor &>/dev/null; then
    wget -q https://github.com/kubecolor/kubecolor/releases/download/v0.4.0/kubecolor_0.4.0_linux_amd64.tar.gz -O /tmp/kubecolor.tar.gz
    sudo tar -xzf /tmp/kubecolor.tar.gz -C /usr/local/bin kubecolor
fi

echo ">> Installing kubefwd..."
if ! command -v kubefwd &>/dev/null; then
    KUBEFWD_URL=$(curl -fsSL https://api.github.com/repos/txn2/kubefwd/releases/latest | grep -oP '"browser_download_url":\s*"\K[^"]*Linux_x86_64\.tar\.gz(?=")')
    wget -q "$KUBEFWD_URL" -O /tmp/kubefwd.tar.gz
    sudo tar -xzf /tmp/kubefwd.tar.gz -C /usr/local/bin kubefwd
fi

echo ">> Installing kubectl krew plugins (tree, neat, images, who-can)..."
if command -v kubectl-krew &>/dev/null || [ -d "${HOME}/.krew" ]; then
    kubectl krew install tree 2>/dev/null || true
    kubectl krew install neat 2>/dev/null || true
    kubectl krew install images 2>/dev/null || true
    kubectl krew install who-can 2>/dev/null || true
fi

echo ""
echo "=== Done! Run 'source ~/.zshrc' to activate. ==="
