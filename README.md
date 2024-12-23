# CKS

## Resources

[Kubernetes CKS Full Course Theory + Practice + Browser Scenarios](https://www.youtube.com/watch?v=d9xfB5qaOfg)
[Kubernetes Security Best Practices - Ian Lewis, Google](https://youtu.be/wqsUfvRyYpw?si=vrIh_1r18fpo8i3K)
[OpenSSL Certificate Authority](https://jamielinux.com/docs/openssl-certificate-authority)

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

They have been downloaded, adapted and saved in the `formation/01-cluster-setup` directory.

In the first terminal, move to Vagrantfile directory and run the following commands:

```shell
vagrant ssh vm1
bash 01-cluster-setup/install_master.sh
```

Open a new terminal, move to Vagrantfile directory and run the following commands:

```shell
vagrant ssh vm2
bash 01-cluster-setup/install_worker.sh
```

#### Network Security Policy

- NetworkPolicies
- Default Deny
- Scenarios

##### Hands-on GUI elements

Install `helm`:

```shell
curl -Lo helm-v3.16.4-linux-amd64.tar.gz https://get.helm.sh/helm-v3.16.4-linux-amd64.tar.gz
tar -xf helm-v3.16.4-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin/
rm -rf linux-amd64/ helm-v3.16.4-linux-amd64.tar.gz
```

Install `kubernetes-dashboard`:

```shell
# Add kubernetes-dashboard repository
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
# Deploy a Helm Release named "kubernetes-dashboard" using the kubernetes-dashboard chart
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard
```

###### Extra: *install `helm-controller`*

```shell
helm install helm-controller oci://registry.gitlab.com/xrow-public/helm-controller/charts/helm-controller --version 0.0.5 --namespace kube-system
```

#### Secure Ingress

##### Hands-on Secure Ingress

Install nginx ingress controller:

```shell
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --create-namespace --namespace ingress-nginx --set controller.kind=DaemonSet --set controller.service.enabled=false --set controller.tolerations[0].key=node-role.kubernetes.io/control-plane --set controller.tolerations[0].operator=Exists --set controller.tolerations[0].effect=NoSchedule --set controller.hostNetwork=true --set controller.admissionWebhooks.service.enabled=true
```

Create a local Certificate Authority (CA):

From this `README.md` folder, run the following commands:

```shell
# Create the root key
openssl genrsa -out formation/pki/private/ca.key.pem 4096

# Assign the relevant permissions
chmod 400 formation/pki/private/ca.key.pem

# Create the root certificate
openssl req -new -x509 -days 365 -sha256 -extensions v3_ca \
  -config formation/pki/openssl.cnf \
  -key formation/pki/private/ca.key.pem \
  -out formation/pki/certs/ca.cert.pem

# Create mandatory files if missing
[[ ! -f formation/pki/index.txt ]] && touch formation/pki/index.txt
[[ ! -f formation/pki/serial ]] && echo 1000 > formation/pki/serial

# Create a key
openssl genrsa -out formation/pki/private/local-ingress.key.pem 4096

# Assign relevant permissions
chmod 400 formation/pki/private/local-ingress.key.pem

# Create a certificate signing request
openssl req -new -sha256 -config formation/pki/127.0.0.1.nip.io.cnf \
    -key formation/pki/private/local-ingress.key.pem \
    -out formation/pki/csr/local-ingress.csr.pem

# Sign the certificate
openssl ca -batch -extensions server_cert -days 30 -notext -md sha256 \
    -config formation/pki/127.0.0.1.nip.io.cnf \
    -in formation/pki/csr/local-ingress.csr.pem \
    -out formation/pki/certs/local-ingress.cert.pem
```

Once generated, update your local trusted certificate authorities with the `formation/pki/certs/ca.cert.pem` file.

To create a secret with the certificate and key, run the following command:

```shell
k create secret tls secure-ingress --cert=$HOME/cks/pki/certs/local-ingress.cert.pem --key=$HOME/cks/pki/private/local-ingress.key.pem
```
