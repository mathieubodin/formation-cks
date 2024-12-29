# Upgrade Kubernetes

Here, we focus on upgrading a Kubernetes cluster, created using the `kubeadm` tool.

## Prerequisites

We need a Kubernetes cluster created using `kubeadm`. We will reuse the same process to create the virtual virtual machines: Setup two virtual machines using Vagrant, process with customized scripts to install Kubernetes on each nodes. Use `install_master.sh` and `install_worker` from this folder.

## Steps

1. Drain the cluster controlplane node. Ignore daemonsets.
2. Upgrade the `kubeadm` tool on the controlplane nodes.
3. Upgrade the kubernetes components of the controlplane with `kubeadm`.
4. Upgrade the `kubelet` and `kubectl` on the controlplane nodes. Restart the kubelet service.
5. Uncordon the controlplane.
6. Repeat the above steps for the other controlplane nodes.
7. Drain the worker node. Ignore daemonsets.
8. Upgrade the `kubeadm` tool on the worker.
9. Upgrade the kubernetes components of the worker with `kubeadm`.
10. Upgrade the kubelet and kubectl on the worker. Restart the kubelet service.
11. Uncordon the worker.
12. Repeat the above steps for the other worker nodes.
