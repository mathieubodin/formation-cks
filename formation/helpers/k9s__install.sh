#!/bin/env bash

if ! command -v k9s &> /dev/null; then
    curl -L https://github.com/derailed/k9s/releases/download/v0.32.7/k9s_Linux_amd64.tar.gz | tar -xz -C /tmp
    sudo mv /tmp/k9s /usr/local/bin/k9s
    sudo chmod +x /usr/local/bin/k9s

    echo
    echo
    echo 'k9s installed successfully'
fi