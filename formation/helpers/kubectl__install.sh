#!/bin/env bash

sudo mkdir -p /etc/apt/keyrings

if [ ! -f /etc/apt/keyrings/kubernetes-1-31-apt-keyring.gpg ]; then
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-1-31-apt-keyring.gpg
fi

if [ ! -f /etc/apt/sources.list.d/kubernetes.list ]; then
    echo | sudo tee /etc/apt/sources.list.d/kubernetes.list
fi

if ! grep -q "signed-by=/etc/apt/keyrings/kubernetes-1-31-apt-keyring.gpg]" /etc/apt/sources.list.d/kubernetes.list; then
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-1-31-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
fi

sudo apt update && sudo apt install -y kubectl=1.31.1-1.1 bash-completion

if ! grep -q 'source <(kubectl completion bash)' $HOME/.bashrc; then
    echo 'source <(kubectl completion bash)' >> $HOME/.bashrc
fi

if ! grep -q 'alias k=kubectl' $HOME/.bashrc; then
    echo 'alias k=kubectl' >> $HOME/.bashrc
fi

if ! grep -q 'complete -F __start_kubectl k' $HOME/.bashrc; then
    echo 'complete -F __start_kubectl k' >> $HOME/.bashrc
fi

echo
echo
echo 'kubectl installed successfully'
echo 'source $HOME/.bashrc to load kubectl completion and alias'
