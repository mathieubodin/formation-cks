#!/bin/sh

# Source: https://raw.githubusercontent.com/killer-sh/cks-course-environment/refs/heads/master/cluster-setup/install_worker.sh
# Source: http://kubernetes.io/docs/getting-started-guides/kubeadm

set -e

source /etc/lsb-release
if [ "$DISTRIB_RELEASE" != "20.04" ]; then
    echo "################################# "
    echo "############ WARNING ############ "
    echo "################################# "
    echo
    echo "This script only works on Ubuntu 20.04!"
    echo "You're using: ${DISTRIB_DESCRIPTION}"
    echo "Better ABORT with Ctrl+C. Or press any key to continue the install"
    read
fi

KUBE_VERSION=1.30.1

# get platform
PLATFORM=`uname -p`

if [ "${PLATFORM}" == "aarch64" ]; then
  PLATFORM="arm64"
elif [ "${PLATFORM}" == "x86_64" ]; then
  PLATFORM="amd64"
else
  echo "${PLATFORM} has to be either amd64 or arm64/aarch64. Check containerd supported binaries page"
  echo "https://github.com/containerd/containerd/blob/main/docs/getting-started.md#option-1-from-the-official-binaries"
  exit 1
fi

### setup terminal
sudo apt update
sudo apt install -y bash-completion binutils
echo 'colorscheme ron' >> ~/.vimrc
echo 'set tabstop=2' >> ~/.vimrc
echo 'set shiftwidth=2' >> ~/.vimrc
echo 'set expandtab' >> ~/.vimrc
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'alias c=clear' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc
sed -i '1s/^/force_color_prompt=yes\n/' ~/.bashrc


### disable linux swap and remove any existing swap partitions
sudo swapoff -a
sudo sed -i '/\sswap\s/ s/^\(.*\)$/#\1/g' /etc/fstab


### remove packages
sudo kubeadm reset -f || true
crictl rm --force $(crictl ps -a -q) || true
sudo apt-mark unhold kubelet kubeadm kubectl || true
sudo apt remove -y docker.io containerd kubelet kubeadm kubectl || true
sudo apt autoremove -y
sudo systemctl daemon-reload

### install podman
# . /etc/os-release
# echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:testing.list
# curl -L "http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | sudo apt-key add -
# sudo apt update -qq
# sudo apt -qq -y install podman cri-tools containers-common
# sudo rm /etc/apt/sources.list.d/devel:kubic:libcontainers:testing.list
# cat <<EOF | sudo tee /etc/containers/registries.conf
# [registries.search]
# registries = ['docker.io']
# EOF

### install packages
sudo apt install -y apt-transport-https ca-certificates
sudo mkdir -p /etc/apt/keyrings
sudo rm /etc/apt/keyrings/kubernetes-1-31-apt-keyring.gpg || true
sudo rm /etc/apt/keyrings/kubernetes-1-30-apt-keyring.gpg || true
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-1-31-apt-keyring.gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-1-30-apt-keyring.gpg
echo | sudo tee /etc/apt/sources.list.d/kubernetes.list
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-1-31-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-1-30-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y docker.io containerd kubelet=${KUBE_VERSION}-1.1 kubeadm=${KUBE_VERSION}-1.1 kubectl=${KUBE_VERSION}-1.1
sudo apt-mark hold kubelet kubeadm kubectl


### install containerd 1.6 over apt-installed-version
# wget https://github.com/containerd/containerd/releases/download/v1.6.12/containerd-1.6.12-linux-${PLATFORM}.tar.gz
# tar xvf containerd-1.6.12-linux-${PLATFORM}.tar.gz
# sudo systemctl stop containerd
# sudo mv bin/* /usr/bin
# rm -rf bin containerd-1.6.12-linux-${PLATFORM}.tar.gz
# sudo systemctl unmask containerd
# sudo systemctl start containerd


### containerd
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

### containerd config
# cat <<EOF | sudo tee /etc/containerd/config.toml
# disabled_plugins = []
# imports = []
# oom_score = 0
# plugin_dir = ""
# required_plugins = []
# root = "/var/lib/containerd"
# state = "/run/containerd"
# version = 2

# [plugins]

#   [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
#     [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
#       base_runtime_spec = ""
#       container_annotations = []
#       pod_annotations = []
#       privileged_without_host_devices = false
#       runtime_engine = ""
#       runtime_root = ""
#       runtime_type = "io.containerd.runc.v2"

#       [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
#         BinaryName = ""
#         CriuImagePath = ""
#         CriuPath = ""
#         CriuWorkPath = ""
#         IoGid = 0
#         IoUid = 0
#         NoNewKeyring = false
#         NoPivotRoot = false
#         Root = ""
#         ShimCgroup = ""
#         SystemdCgroup = true
# EOF
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -e 's/SystemdCgroup = false/SystemdCgroup = true/g' -i /etc/containerd/config.toml

### crictl uses containerd as default
{
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
EOF
}

### kubelet should use containerd
{
cat <<EOF | sudo tee /etc/default/kubelet
KUBELET_EXTRA_ARGS="--container-runtime-endpoint unix:///run/containerd/containerd.sock"
EOF
}

### start services
sudo systemctl daemon-reload
sudo systemctl enable containerd
sudo systemctl restart containerd
sudo systemctl enable kubelet && sudo systemctl start kubelet

### init k8s
sudo kubeadm reset -f
sudo systemctl daemon-reload
sudo service kubelet start

echo
echo "EXECUTE ON MASTER: kubeadm token create --print-join-command --ttl 1h"
echo "THEN RUN THE OUTPUT AS COMMAND HERE TO ADD AS WORKER"
echo
