#! /bin/env bash

if ! command -v helm &> /dev/null
then
    echo "helm could not be found, installing it..."
    curl -sL https://get.helm.sh/helm-v3.16.4-linux-amd64.tar.gz | sudo tar -xz -C /usr/local/bin --strip-components=1 linux-amd64/helm
fi

if ! grep -q 'source <(helm completion bash)' $HOME/.bashrc; then
    echo 'source <(helm completion bash)' >> $HOME/.bashrc
fi

echo
echo
echo 'helm installed successfully'
echo 'source $HOME/.bashrc to load helm completion'