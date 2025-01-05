#!/bin/env bash



if free | awk '/^Swap:/ {exit !$2}'; then
    sudo swapoff -a
fi

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

sudo apt update && sudo apt install -y curl apt-transport-https vim git wget gnupg2 software-properties-common apt-transport-https ca-certificates socat jq

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

    containerd config default | sudo tee /etc/containerd/config.toml
    sudo sed -e 's/SystemdCgroup = false/SystemdCgroup = true/g' -i /etc/containerd/config.toml

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

    sudo kubeadm init --kubernetes-version=1.31.1 \
        --apiserver-advertise-address=$(hostname -i) \
        --ignore-preflight-errors=NumCPU \
        --skip-token-print \
        --service-cidr 10.96.0.0/16 \
        --pod-network-cidr 10.244.0.0/16 \
        --node-name cks-master
    
    l_helpers_root=$( dirname -- "${BASH_SOURCE[0]}" | xargs readlink -f)

    sudo kubeadm kubeconfig user \
        --config cks-master_kubeadm__initconfiguration.yaml \
        --org system:nodes \
        --client-name system:node:cks-worker-1 \
        | tee $l_helpers_root/configurations/cks-worker-1_kubelet__kubeconfig.yaml
    
    sudo kubeadm kubeconfig user \
        --config cks-master_kubeadm__initconfiguration.yaml \
        --org system:nodes \
        --client-name system:node:cks-worker-2 \
        | tee $l_helpers_root/configurations/cks-worker-2_kubelet__kubeconfig.yaml

    sudo apt-mark hold kubeadm

    mkdir -p $HOME/.kube
    sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
fi

if ! dpkg -l | grep -q kubectl; then
    sudo apt install -y kubectl=1.31.1-1.1
    sudo apt-mark hold kubectl
fi

if ! command -v cilium &> /dev/null; then
    l_cilium_cli_version=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/master/stable.txt)

    curl -L https://github.com/cilium/cilium-cli/releases/download/$l_cilium_cli_version/cilium-linux-amd64.tar.gz | sudo tar -xz -C /usr/local/bin cilium
fi

if [ $(kubectl get node cks-master -o json | grep NetworkReady=false | wc -l) -eq 1 ]; then 
    l_stable_version=$(cilium version | grep '(stable)' | cut -d' ' -f 4)
    cilium install --version=$l_stable_version \
        --set ipam.mode=kubernetes

    kubectl -n kube-system wait --for=condition=Ready -l app.kubernetes.io/part-of=cilium pod

    echo 'source <(cilium completion bash)' >> $HOME/.bashrc
fi

echo
echo
echo 'kubernetes controlplane installed successfully'
echo 'add more workers to the cluster'
echo 'source $HOME/.bashrc to load helm completion'
