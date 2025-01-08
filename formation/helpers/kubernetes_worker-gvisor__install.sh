#!/bin/env bash

if free | awk '/^Swap:/ {exit !$2}'; then
    sudo swapoff -a

    sudo sed -i '/\sswap\s/ s/^\(.*\)$/#\1/g' /etc/fstab

    l_swap_service=$(systemctl show -p Id swap.target | cut -d= -f2)

    if [ -n "$l_swap_service" ]; then
        sudo systemctl stop $l_swap_service
        sudo systemctl mask $l_swap_service
    fi
fi

if ! dpkg -l | grep -wq "curl"; then
    sudo apt install -y curl
fi

if ! dpkg -l | grep -wq "gnupg2"; then
    sudo apt install -y gnupg2
fi

sudo mkdir -p /etc/apt/keyrings

if [ ! -f /etc/apt/keyrings/gvisor-archive-keyring.gpg ]; then
    curl -fsSL https://gvisor.dev/archive.key | sudo gpg --dearmor -o /etc/apt/keyrings/gvisor-archive-keyring.gpg
fi

if [ ! -f /etc/apt/sources.list.d/gvisor.list ]; then
    echo | sudo tee /etc/apt/sources.list.d/gvisor.list
fi

if ! grep -q "signed-by=/etc/apt/keyrings/gvisor-archive-keyring.gpg" /etc/apt/sources.list.d/gvisor.list; then
    echo "deb [signed-by=/etc/apt/keyrings/gvisor-archive-keyring.gpg] https://storage.googleapis.com/gvisor/releases release main" | sudo tee -a /etc/apt/sources.list.d/gvisor.list
fi

if [ ! -f /etc/apt/keyrings/kubernetes-1-31-apt-keyring.gpg ]; then
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-1-31-apt-keyring.gpg
fi

if [ ! -f /etc/apt/sources.list.d/kubernetes.list ]; then
    echo | sudo tee /etc/apt/sources.list.d/kubernetes.list
fi

if ! grep -q "signed-by=/etc/apt/keyrings/kubernetes-1-31-apt-keyring.gpg]" /etc/apt/sources.list.d/kubernetes.list; then
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-1-31-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
fi

sudo apt update && sudo apt install -y apt-transport-https vim git wget software-properties-common apt-transport-https ca-certificates socat jq runsc

if ! dpkg -l | grep -q kubelet; then
    sudo apt install -y docker.io containerd kubelet=1.31.1-1.1

    cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

    sudo modprobe overlay
    sudo modprobe br_netfilter

    cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

    sudo sysctl --system
    sudo mkdir -p /etc/containerd

    cat <<EOF | sudo tee /etc/containerd/config.toml
version = 2
[plugins."io.containerd.runtime.v1.linux"]
  shim_debug = true
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF

    cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
EOF

    cat <<EOF | sudo tee /etc/default/kubelet
KUBELET_EXTRA_ARGS="--container-runtime-endpoint unix:///run/containerd/containerd.sock"
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable containerd
    sudo systemctl restart containerd
    sudo systemctl enable kubelet && sudo systemctl start kubelet
    sudo apt-mark hold kubelet
fi

if ! dpkg -l | grep -q kubeadm; then
    sudo apt install -y kubeadm=1.31.1-1.1

    sudo kubeadm config images pull --kubernetes-version=1.31.1
   
    sudo apt-mark hold kubeadm
fi

l_helpers_root=$( dirname -- "${BASH_SOURCE[0]}" | xargs readlink -f)

if [ ! -f $l_helpers_root/configurations/cks-worker-gvisor_kubelet__kubeconfig.yaml ]; then
    echo "Missing worker configuration file, exiting..."
    exit 1
fi

sudo mkdir -p /etc/kubernetes

sudo cp $l_helpers_root/configurations/cks-worker-gvisor_kubelet__kubeconfig.yaml /etc/kubernetes/kubelet.conf

sudo systemctl daemon-reload
sudo systemctl restart kubelet

sudo kubeadm join \
    --discovery-file /etc/kubernetes/kubelet.conf \
    --ignore-preflight-errors=FileAvailable--etc-kubernetes-kubelet.conf

echo
echo
echo 'kubernetes worker-gvisor installed successfully'
