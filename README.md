# CKS

## Resources

[Kubernetes CKS Full Course Theory + Practice + Browser Scenarios](https://www.youtube.com/watch?v=d9xfB5qaOfg)
[Kubernetes Security Best Practices - Ian Lewis, Google](https://youtu.be/wqsUfvRyYpw?si=vrIh_1r18fpo8i3K)

## Introduction and welcome

For hands-on practice, I need a two nodes cluster setup with `kubeadm`.

### Security best practices

- Security Principles
- K8s Security Categories
- K8s Best Practices

#### Security Principles

- Defense in depth
  - Multiple layers of security
  - Redundant security measures
- Principle of least privilege
  - Only give the permissions that are required
- Limiting the attack surface
  - Reduce the number of entry points

#### K8s Security Categories

- Host Operating System Security
- Kubenrtetes Cluster Security
- Application Security

##### Host OS Security

- Kubernetes Nodes should only do one thing: Kubernetes
- Reduce Attack Surface
  - Remove unnecessary applications
  - Keep up to date
- Runtime Secutiry Tools
- Find and identify malicious processes
- Restrict IAM /SSH access

##### Kubernetes Cluster Security

- Kubernetes componenets are running secure and up)to-date
  - API Server
  - Kubelet
  - ETCD (Encryption at rest, Restrict access to ETCD, Encrypt Traffic to ETCD)
- Restrict (external) access
- Use Authentication -> Authorization
- Adminssion Controllers
  - NodeRestriction
  - Custom Policies (OPA, Kyverno)
- Enable Audit Logging
- Secutiry Benchmarking
  - CIS

##### Application Security

- Use Secrets / no hardcoded credentials
- RBAC
- Container Sandboxing
- Container Hardening
  - Attack Surface
  - Ruan as User
  - Read-Only Filesystem
- Vulnerability Scanning
- mTLS / ServiceMeshes

### Cluster Setup

VM1: Master `cks-master`
OS: Ubuntu 20.04 LTS
DISK: 50GB
CPU: 2
RAM: 4GB

VM2: Worker `cks-worker`
OS: Ubuntu 20.04 LTS
DISK: 50GB
CPU: 2
RAM: 4GB

Virtual machines are created using Vagrant. Check the `Vagrantfile` for more details.

Run the following commands to setup the cluster:

```shell
# From this README.md file directory
vagrant up
# To finish the initial upgrade
vagrant reload
```

Installation scripts are provided by `killer-sh` in the following links:

- [Master](https://raw.githubusercontent.com/killer-sh/cks-course-environment/refs/heads/master/cluster-setup/latest/install_master.sh)
- [Worker](https://raw.githubusercontent.com/killer-sh/cks-course-environment/refs/heads/master/cluster-setup/latest/install_worker.sh)

They have been downloaded, adapted and saved in the `cluster-setup` directory.

In the first terminal, move to Vagrantfile directory and run the following commands:

```shell
vagrant ssh vm1
bash cluster-setup/install_cks-master.sh
```

Open a new terminal, move to Vagrantfile directory and run the following commands:

```shell
vagrant ssh vm2
bash cluster-setup/install_cks-worker.sh
```

#### Network Security Policy

- NetworkPolicies
- Default Deny
- Scenarios

#### Hans-on

Install `helm`:

```shell
wget https://get.helm.sh/helm-v3.16.4-linux-amd64.tar.gz
tar -xf helm-v3.16.4-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin/
```

Install `helm-controller`:

```shell
helm install helm-controller oci://registry.gitlab.com/xrow-public/helm-controller/charts/helm-controller --version 0.0.5 --namespace kube-system
```
