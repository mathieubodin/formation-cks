# CKS

## Resources

- [Kubernetes CKS Full Course Theory + Practice + Browser Scenarios](https://www.youtube.com/watch?v=d9xfB5qaOfg)
- [Kubernetes Security Best Practices - Ian Lewis, Google](https://youtu.be/wqsUfvRyYpw?si=vrIh_1r18fpo8i3K)
- [Martin White - Consistent Security Controls through CIS Benchmarks](https://youtu.be/53-v3stlnCo?si=-ulNwAyFuU55I9P-)
- [OpenSSL Certificate Authority](https://jamielinux.com/docs/openssl-certificate-authority)
- [OCI, CRI, ?? : Comprendre le paysage d'exécution des conteneurs dans Kubernetes - Phil Estes, IBM](https://youtu.be/RyXL1zOa8Bw?si=Wy80Kw43zWHlLuWk)
- [Kata Containers An introduction and overview](https://youtu.be/4gmLXyMeYWI?si=paSt1VNWLqnvFkHH)

## Introduction and welcome

For hands-on practice, I need a two nodes cluster setup with `kubeadm`.

## Security best practices

- Security Principles
- K8s Security Categories
- K8s Best Practices

### Security Principles

- Defense in depth
  - Multiple layers of security
  - Redundant security measures
- Principle of least privilege
  - Only give the permissions that are required
- Limiting the attack surface
  - Reduce the number of entry points

### K8s Security Categories

- Host Operating System Security
- Kubenrtetes Cluster Security
- Application Security

#### Host OS Security

- Kubernetes Nodes should only do one thing: Kubernetes
- Reduce Attack Surface
  - Remove unnecessary applications
  - Keep up to date
- Runtime Secutiry Tools
- Find and identify malicious processes
- Restrict IAM /SSH access

#### Kubernetes Cluster Security

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

#### Application Security

- Use Secrets / no hardcoded credentials
- RBAC
- Container Sandboxing
- Container Hardening
  - Attack Surface
  - Ruan as User
  - Read-Only Filesystem
- Vulnerability Scanning
- mTLS / ServiceMeshes

## Cluster Setup

VM1: Master `cks-master`
OS: Ubuntu 20.04 LTS
DISK: 50GB
CPU: 2
RAM: 2GB

VM2: Worker `cks-worker`
OS: Ubuntu 20.04 LTS
DISK: 50GB
CPU: 2
RAM: 2GB

VM3: Worker `cks-worker-gvisor`
OS: Ubuntu 20.04 LTS
DISK: 50GB
CPU: 2
RAM: 2GB

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

## Network Security Policy

- NetworkPolicies
- Default Deny
- Scenarios

### Hands-on GUI elements

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

#### Extra: *install `helm-controller`*

```shell
helm install helm-controller oci://registry.gitlab.com/xrow-public/helm-controller/charts/helm-controller --version 0.0.5 --namespace kube-system
```

## Secure Ingress

### Hands-on Secure Ingress

Install nginx ingress controller:

```shell
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --create-namespace --namespace ingress-nginx --set controller.kind=DaemonSet --set controller.service.enabled=false --set controller.hostNetwork=true --set controller.admissionWebhooks.service.enabled=true
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

## Node Metadata protection

- Metadata API available on virtual machines spun up in cloud providers
- Metadata API can be used to get sensitive information
- Pods on worker nodes can access the metadata API
- Metadata API access should be restricted to pods that need it, through Network Policies for example.

## Use CIS Benchmarks to review security configurations

- CIS Benchmarks are a set of best practices for securing a system
- CIS Benchmarks are available for Kubernetes

### Hands-on CIS Benchmarks in action

We'll use `kube-bench` to check the cluster against the CIS benchmarks. It will be run on the master node from within a container.

```shell
sudo docker run --pid=host -v /etc:/etc:ro -v /var:/var:ro -t docker.io/aquasec/kube-bench:latest --version 1.31
```

This can be done also on the worker node.

## Verify platform binaries

- Verify the checksum of the binaries with hashes, which is a *finger print*.
- The process is quite simple: download the binary, download the hash, and compare the latter with the one you would compute for the binary.

### Hands-on Verify platform binaries

First, download the data from the official Kubernetes website:

```shell
curl -Lo formation/07-verify-platform-binaries/kubernetes-server-linux-amd64.tar.gz https://dl.k8s.io/v1.32.0/kubernetes-server-linux-amd64.tar.gz
```

Then, fetch the hash: hereafter is the sha512 hash for the version [1.32.0](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.32.md#server-binaries)

```hash
09ffc69de339bb507a9f8fdd2206dcc1e77f58184bfa1f771c715edc200861131e5028ae38ec1f5a1112d3303159fb2b9246266114ce0a502776b2c28354dfba
```

Finally, compute the hash of the downloaded file:

```shell
vagrant ssh vm1
cd 07-verify-platform-binaries
echo "09ffc69de339bb507a9f8fdd2206dcc1e77f58184bfa1f771c715edc200861131e5028ae38ec1f5a1112d3303159fb2b9246266114ce0a502776b2c28354dfba" | \
  tee checksum && sha512sum kubernetes-server-linux-amd64.tar.gz | \
  cut -d ' ' -f 1 | tee -a checksum \
  && cat checksum | uniq | wc -l | grep -q 1 && echo "Checksums match" || echo "Checksums do not match"
```

Let's check the binary of the current kubeapi-server. Before that we need to determine the server version and to do so we would need `jq`. Then we should download the binary, untar it, compute the hash of the current running binary and compare it with the one of the downloaded server.

```shell
vagrant ssh vm1
cd 07-verify-platform-binaries
# Install jq
sudo apt update && sudo apt install -y jq
# Get the server version
RUNNING_SERVER_VERSION=$(k version -o json | jq -r '.serverVersion.gitVersion')
# Download the server binary
curl -Lo kubernetes-server-linux-amd64.tar.gz https://dl.k8s.io/${RUNNING_SERVER_VERSION}/kubernetes-server-linux-amd64.tar.gz
# Untar the binary
tar -xvf kubernetes-server-linux-amd64.tar.gz
# Compute the hash of the downloaded server binary
sha512sum kubernetes/server/bin/kube-apiserver | cut -d ' ' -f 1 | tee checksum
# Get the pid of the running kube-apiserver process
RUNNING_SERVER_PID=$(ps aux | grep kube-apiserver | grep -v grep | awk '{print $2}')
# Compute the hash of the running server binary. This is done by accessing the binary through the /proc filesystem
sudo sha512sum /proc/$RUNNING_SERVER_PID/root/usr/local/bin/kube-apiserver | cut -d ' ' -f 1 | tee -a checksum
# Compare the hashes
cat checksum | uniq | wc -l | grep -q 1 && echo "Checksums match" || echo "Checksums do not match"
# Clean up the files
rm -rf checksum kubernetes-server-linux-amd64.tar.gz kubernetes
```

## Cluster Hardening

- RBAC
- ServiceAccounts
- Restrict API access
- Upgrade Kubernetes

### RBAC

- Role Based Access Control
- Define roles and bind them to users
- Define what is allowed, otherwise it is denied. Permissions are *additive*.
  - Deny is not possible, only *"whitelisting"*
- Enforce the principle of least privilege

The following table shows the permissions available and where they are applied:

<!-- markdownlint-disable MD033 -->
<table>
  <thead>
    <tr>
      <th colspan="2">where are the permissions available?</th>
      <th colspan="2">where are the permissions applied?</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>In on namespace -></td>
      <td>Role</td>
      <td>applied in one namespace -></td>
      <td>RoleBinding</td>
    </tr>
    <tr>
      <td>In all namespaces -><br>+ non namespaced</td>
      <td>ClusterRole</td>
      <td>applied in all namespaces -><br>+ non namespaced</td>
      <td>ClusterRoleBinding</td>
    </tr>
  </tbody>
  <tfoot>
    <tr>
      <td colspan="2">
        <p>set of permissions</p>
        <ul>
          <li>"can edit pods"</li>
          <li>"can read secrets"</li>
        </ul>
      </td>
      <td colspan="2">
        <p>who gets a set of permissions</p>
        <ul>
          <li>"bind a Role/ClusterRole to something"</li>
        </ul>
    </tr>
</table>
<!-- markdownlint-enable MD033 -->

Reminder:

1. A set of permissions (Role or ClusterRole) **can** be granted to an identity at a namespace level (with RoleBinding). A ClusterRole **can** also be granted to an identity at a cluster level (with ClusterRoleBinding).
2. When a ClusterRole is granted to an identity through a ClusterRoleBinding, the permissions are granted **across all namespaces, now and in the future**.
3. A Role **can't** be granted to an identity at a cluster level (with ClusterRoleBinding).

#### Hands-on RBAC

Let's work with Roles and RoleBindings in the `08-rbac` directory.

```shell
vagrant ssh vm1
cd 08-rbac
k create ns red --dry-run=client -o yaml | tee red_ns.yaml
k create ns blue --dry-run=client -o yaml | tee blue_ns.yaml
k -n red create role secret-manager --verb=get --resource=secrets --dry-run=client -o yaml | tee red_secret-manager__role.yaml
k -n red create rolebinding secret-manager --role=secret-manager --user=jane --dry-run=client -o yaml | tee red_secret-manager__rolebinding.yaml
k -n blue create role secret-manager --verb=get,list --resource=secrets --dry-run=client -o yaml | tee blue_secret-manager__role.yaml
k -n blue create rolebinding secret-manager --role=secret-manager --user=jane --dry-run=client -o yaml | tee blue_secret-manager__rolebinding.yaml
k apply -f .
# Check the permissions with kubectl auth can-i
k -n red auth can-i get secrets --as=jane
k -n blue auth can-i get secrets --as=jane
k -n red auth can-i list secrets --as=jane
k -n blue auth can-i list secrets --as=jane
```

Now, let's work with ClusterRoles and ClusterRoleBindings in the `08-rbac` directory.

```shell
vagrant ssh vm1
cd 08-rbac
k create clusterrole deploy-deleter --verb=delete --resource=deployments --dry-run=client -o yaml | tee deploy-deleter__clusterrole.yaml
k -n red create rolebinding deploy-deleter --clusterrole=deploy-deleter --user=jim --dry-run=client -o yaml | tee red_deploy-deleter__rolebinding.yaml
k apply -f .
# Check the permissions with kubectl auth can-i
k -n red auth can-i delete deployments --as=jim
k -n blue auth can-i delete deployments --as=jim
k -n red auth can-i delete deployments --as=jane
k -n blue auth can-i delete deployments --as=jane
k auth can-i delete deployments --as=jane -A
```

### Accounts

- ServiceAccounts
- *normal* accounts

There is no k8s User resource. Instead, the identity is provided by the authentication system.
The identity is held in the *subject* field (*"CN"*) of the certificate, signed by the CA of the cluster.

Reminder:

1. **There in no way to invalidate a certificate**.
2. **If a certificate has been leaked**
    - Remove all access via RBAC
    - Username cannot be used until the certificate expires
    - Create new CA and re-issue all certificates

#### Hands-on Accounts

Let's create a certificate+key and authenticate as user jane

Reminder of the steps:

1. Create a key
2. Create a certificate signing request (CSR)
3. Upload a CertificateSigningRequest in the cluster
4. Approve the CertificateSigningRequest and get the certificate
5. Update KubeConfig with the new user certificate

```shell
vagrant ssh vm1
cd 09-accounts
openssl genrsa -out jane.key 4096
openssl req -new -key jane.key -out jane.csr
# Fetch th CSR content, encode it in base64 and save it in the file `jane__certificatesigningrequest.yaml` in the `.spec.request` field.
cat jane.csr | base64 -w 0
# Create the CSR resource in the cluster
k apply -f jane__certificatesigningrequest.yaml
# Approve the CSR
k certificate approve jane
# Fetch the certificate and save it in the file `jane.crt`
k get csr jane -o jsonpath='{.status.certificate}' | base64 -d > jane.crt
# Update the kubeconfig file
k config set-credentials jane --client-certificate=jane.crt --client-key=jane.key --embed-certs=true
k config set-context jane --user=jane --cluster=kubernetes --namespace=default
# Check the new user in the kubeconfig file
k config view
```

Now, practice more with the user jim

```shell
vagrant ssh vm1
cd 09-accounts
openssl genrsa -out jim.key 4096
openssl req -new -key jim.key -out jim.csr
cat jim.csr | base64 -w 0
k apply -f jim__certificatesigningrequest.yaml
k certificate approve jim
k get csr jim -o jsonpath='{.status.certificate}' | base64 -d > jim.crt
k config set-credentials jim --client-key=jim.key --client-certificate=jim.crt --embed-certs=true
k config set-context jim --user=jim --cluster=kubernetes --namespace=default
k config view
```

### Service Accounts

- Service Accounts are used by pods to authenticate to the API server
- Service Accounts are namespaced, there is a `default` Service Account in each namespace
- Service Accounts token are automatically mounted in pods as a volume.

Reminder:

1. **Does my pod need a Service Account?**
    - If the pod needs to interact with the API server, it needs a Service Account.
    - Otherwise, most of the time, it does not need a Service Account.
    - Then, **do not mount the Service Account token in the pod**.
2. **Do not use the `default` Service Account**.
    - Create a Service Account for each pod.
3. **Control permissions granted to each Service Account.**
    - embrace the principle of least privilege.

#### Hands-on Service Accounts

Let's create a service account and a pod that uses it.

```shell
vagrant ssh vm1
cd 10-service-accounts
k create sa accessor
k create token accessor
k -n default run accessor --image=nginx --dry-run=client -o yaml | tee default_accessor__pod.yaml
```

Now, disable the automatic mounting of service account token in the pod.
It can be done in a pod spec with the `automountServiceAccountToken` field. It would mean that the pod does not need to interact with the API server.

Or it can be done in a service account with the `automountServiceAccountToken` field. It would mean that all pods using this service account do not need to interact with the API server.

### Restrict API access

- Authentication, Authorization, Admission Control
- Connect to the API server
- Restrict API access in various ways

Restrictions:

1. **Don't allow anonymous access**
2. **Close insecure port**
3. **Don't expose the APIserver to the outside**
4. **Restrict access from Nodes to API (NodeRestriction)**
5. Prevent unauthorized access (RBAC)
6. Prevent pods from accessing API
7. Apiserver port behind firewall / allowed ip ranges

#### Hands-on Restrict API access

```shell
vagrant ssh vm1
cd 11-restrict-api-access
# Extract ca.crt from kubeconfig
k config view -o=json --raw=true | jq -r '.clusters[0].cluster["certificate-authority-data"]' | base64 -d | tee ca.cert
# Extract client pki from kubeconfig
k config view -o=json --raw=true | jq -r '.users[2].user["client-certificate-data"]' | base64 -d | tee client.cert
k config view -o=json --raw=true | jq -r '.users[2].user["client-key-data"]' | base64 -d | tee client.key
# Extract server url from kubeconfig
export SERVER_URL=$(k config view -o=json --raw=true | jq -r '.clusters[0].cluster["server"]')
# Test the connection
curl $SERVER_URL --cacert ca.cert --cert client.cert --key client.key
```

### Upgrade Kubernetes

Here, we focus on upgrading a Kubernetes cluster, created using the `kubeadm` tool.

#### Prerequisites

We need a Kubernetes cluster created using `kubeadm`. We will reuse the same process to create the virtual virtual machines: Setup two virtual machines using Vagrant, process with customized scripts to install Kubernetes on each nodes.

We will use `install_master.sh` and `install_worker` from this folder in order to setup the cluster in a prior version.

First, destroy the existing virtual machines:

```shell
vagrant destroy -f
```

Then, recreate the virtual machines and install the cluster:

```shell
vagrant up
vagrant reload
vagrant ssh vm1
```

Once connected inside the controlplane node, run the following commands:

```shell
cd 12-upgrade-kubernetes
bash install_master.sh
```

Open a new terminal, connect to the worker node and run the following commands:

```shell
cd 12-upgrade-kubernetes
bash install_worker.sh
```

Proceed with the upgrade of the cluster.

#### Steps

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

## Microservices Vulnerabilities

- Manage Kubernetes Secrets
- Container Runtime Sandboxes
- OS Level Security Domains
- mTLS

### Manage Kubernetes Secrets

Here we will create a simple pod, two secrets `secret1` - mounted in `pod` as a file - and `secret2` - mounted in `pod` as an environment variable.

#### Create the secrets

```shell
k create secret generic secret1 --from-literal=authentication=secretpassword
k create secret generic secret2 --from-literal=login=secretlogin
```

#### Create the pod

```shell
k run pod --image=nginx --dry-run=client -o yaml > pod.yaml
```

Edit the `pod.yaml` file and add the secrets support.

#### Check secrets in `ectd`

```shell
sudo ETCDCTL_API=3 etcdctl \
   --cacert=/etc/kubernetes/pki/etcd/ca.crt   \
   --cert=/etc/kubernetes/pki/etcd/server.crt \
   --key=/etc/kubernetes/pki/etcd/server.key  \
   get /registry/secrets/default/secret1 | hexdump -C | tee secret1__not-crypted.hexdump
```

It should be readable. It should also the case for `secret2`:

```shell
sudo ETCDCTL_API=3 etcdctl \
   --cacert=/etc/kubernetes/pki/etcd/ca.crt   \
   --cert=/etc/kubernetes/pki/etcd/server.crt \
   --key=/etc/kubernetes/pki/etcd/server.key  \
   get /registry/secrets/default/secret2 | hexdump -C | tee secret2__not-crypted.hexdump
```

#### Encrypt the secrets in `etcd`

Prepare a file `encryption-provider-config.yaml`, move it to `/etc/kubernetes/etcd/` on the controlplane. Ensure the `identity` provider is enabled, only for read.

Update the `kube-apiserver` configuration to use the encryption provider: add the `--encryption-provider-config` option to the `kube-apiserver` command line, it should aim the `encryption-provider-config.yaml` file. Add a volume to mount the directory `/etc/kubernetes/etcd` in the `kube-apiserver` pod. Configure a mount path for the volume accordingly.

Restart the `kube-apiserver` on the controlplane. You may speed up the process by restarting the `kube-apiserver` pod or killing the `kube-apiserver` process.

Force the encryption of the secrets in `etcd`:

```shell
k get secret -A -o yaml | k replace -f -
```

Check again the secrets in `etcd`:

```shell
sudo ETCDCTL_API=3 etcdctl \
   --cacert=/etc/kubernetes/pki/etcd/ca.crt   \
   --cert=/etc/kubernetes/pki/etcd/server.crt \
   --key=/etc/kubernetes/pki/etcd/server.key  \
   get /registry/secrets/default/secret1 | hexdump -C | tee secret1__crypted.hexdump
```

It should be encrypted.

### Container Runtime Sandboxes

- *Container are not VMS* - they are not isolated from the host system. They are isolated from each other, but not from the host system. They share the same kernel as the host system.
- Since they share the same kernel as the host, an attacker may use this to their advantage to break out of the container and access the host system.
- To mitigate this, we can use container runtime sandboxes. These helps to reduce the attack surface.

#### Containers and system calls

<!-- markdownlint-disable MD033 -->
<table style="text-align:center;">
  <tr>
    <td style="border-right:1px solid">Container #1</td>
    <td>Container #2</td>
    <td style="border-left:1px dashed" rowspan="3">User space</td>
  </tr>
  <tr>
    <td style="border-right:1px solid">App #1 process</td>
    <td>App #2 process</td>
  </tr>
  <tr>
    <td style="border-right:1px solid">SANDBOX</td>
    <td>SANDBOX</td>
  </tr>
  <tr>
    <td style="border-right:1px solid">System calls</td>
    <td>System calls</td>
    <td style="border-left:1px dashed" rowspan="2">Kernel space</td>
  </tr>
  <tr>
    <td colspan="2">Kernel</td>
  </tr>
  <tr >
    <td colspan="2">Hardware</td>
    <td style="border:none">&nbsp;</td>
  </tr>
</table>
<!-- markdownlint-enable MD034 -->

##### Hands on: Contact the linux kernel from a container

Run a simple container, then exec into it:

```bash
k run pod --image=alpine
k exec -it pod -- uname -r
```

It should return the kernel version of the host system.

#### OCI: Open Container Initiative

- Linux Foundation project to design open standards for virtualization.
- It defines a specification for container runtime, image format and distribution.
- It also supply a reference implementation called `runc`.
- `kubelet` may use any OCI compliant runtime, only one can be used at a time. It is defined in the `kubelet` configuration file, through the `--container-runtime` and `--container-runtime-endpoint` flags.

#### kata containers

- It is based on kightweight VMs with individual kernels.
- It provide a strong separation layer
- Runs every container in its own private VM.
- By default, it uses `QEMU` to run the VMs.

#### gVisor

- It is a user-space kernel, that intercepts system calls and manages them.
- Another layer of isolation between the container and the host system.
- It is **NOT** based on VMs.
- It simulates kernel syscalls with limited functionality, it is written in Go.
- It runs in userspace separated from the host kernel.
- The runtime is called `runsc`.

#### Hands on: RuntimeClass

Create and use a `RuntimeClass` to use `gVisor` as the runtime for a pod.

### OS Level Security Domains

- Security Contexts

#### Security Contexts

- Define privilege and access control for a Pod or Container.
  - userID and groupID
  - Run privileged or unprivileged
  - Linux capabilities
  - etc...
- Security Contexts can be defined at the Pod or Container level. At the Pod level, the security context applies to all Containers in the Pod. At the Container level, the security context is specific to the Container.

##### Security Contexts at the Pod Level

The followings are rules of thumb for defining security contexts at the Pod level.

It must define at least the following:

- `runAsNonRoot`: Run the Pod as a non-root user. Kubelet will not run the Pod as root.
- `runAsUser`: The UID to run the entrypoint of the container process.
- `fsGroup`: The GID to run the entrypoint of the container process.
- `runAsGroup`: The GID to run the entrypoint of the container process.

It should define the following:

- `appArmorProfile`: The AppArmor profile to apply to the container.
- `seccompProfile`: The seccomp profile to apply to the container.

####### Hands-on Security Contexts at the Pod Level

Here we want to force a container to run as a non-root user.

Create a Pod with the following definition:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: container
    image: busybox
    command: ["sleep", "3600"]
```

Create the Pod:

```bash
k apply -f pod.yaml
```

It should be created, but failed to start. Check the status of the Pod:

```bash
k describe pod pod
```

In the events, `kubelet` should complain about "Error: container has runAsNonRoot and image will run as root".

Lets fix the issue by changing the user to run the container as. Update the Pod definition with a `runAsUser` directive. Update the `securityContext` section with the following:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
```

Update the Pod:

```bash
k delete pod pod --force --grace-period=0 && k apply -f pod.yaml
```

The Pod should be created and running. Check the `id` command in the container:

```bash
k exec pod -- id
```

The output should be `uid=1000 gid=0(root) groups=0(root)`. The container is running as the user with UID 1000, but the group is still root.

Let's fix the group issue. Update the Pod definition with a `runAsGroup` directive. Update the `securityContext` section with the following:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 3000
```

Update the Pod:

```bash
k delete pod pod --force --grace-period=0 && k apply -f pod.yaml
```

The Pod should be created and running. Check the `id` command in the container:

```bash
k exec pod -- id
```

The output should be `uid=1000 gid=3000 groups=3000`. The container is running as the user with UID 1000 and GID 3000. The groups is also changed.

###### Extra: work with `fsGroup`

The `fsGroup` directive is used to define the GID to run the entrypoint of the container process. It is used to define the group that owns the volume mounted by the container.

Let's prepare a volume to mount in the container. To  do so, `ssh` into the `cks-worker` node and create a directory:

```bash
mkdir -p /tmp/podvolume
chown 0:2000 /tmp/podvolume
chmod 770 /tmp/podvolume
```

Fron now on, this directory is usable by root and the group with GID 2000. Continue by creating a volume using this directory:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv
spec:
  capacity:
    storage: 100Mi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /tmp/podvolume
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - cks-worker
```

Create the PersistentVolume:

```bash
k apply -f pv.yaml
```

Create a PersistentVolumeClaim:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi
  storageClassName: local-storage
```

Create the PersistentVolumeClaim:

```bash
k apply -f pvc.yaml
```

Update the Pod definition to use the PersistentVolumeClaim:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
  volumes:
    - name: volume
      persistentVolumeClaim:
        claimName: pvc
  containers:
  - name: container
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
      - name: volume
        mountPath: /data
```

Recreate the Pod:

```bash
k delete pod pod --force --grace-period=0 && k apply -f pod.yaml
```

Let's try to write a file in the volume mounted by the container:

```bash
k exec pod -- touch /data/file
```

The command should fail with a permission denied error. This is because the container is running as the user with UID 1000 and GID 3000, but the group owning the volume is 2000. To fix the issue, we need to update the Pod definition with a `fsGroup` directive. Update the `securityContext` section with the following:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 3000
  fsGroup: 2000
```

Update the Pod:

```bash
k delete pod pod --force --grace-period=0 && k apply -f pod.yaml
```

Let's try to write a file in the volume mounted by the container:

```bash
k exec pod -- touch /data/file
```

The command should succeed. The container is running as the user with UID 1000 and GID 3000, and the group owning the volume is 2000. The `fsGroup` directive allows the container to write in the volume.

Verify the file is created:

```bash
k exec pod -- ls -l /data
```

It should contain the `file` file. Good job, the container can write in the volume.

##### Security Contexts at the Container Level

The followings are rules of thumb for defining security contexts at the Container level. It is recommended to define security contexts at the Pod level when possible and only define them at the Container level when necessary.

Remember that the security context at the Container level overrides the security context at the Pod level.

It must define at least the following:

- `privileged`: Run the Container in privileged mode. It should be avoided as much as possible.
- `allowPrivilegeEscalation`: Do not allow privilege escalation. It should be avoided as much as possible.
- `readOnlyRootFilesystem`: Mount the root filesystem as read-only. Writing to the root filesystem should be avoided and authorized only when necessary.
- `capabilities`: Drop all capabilities and add only the necessary ones.

The followings are recommended to be defined at the Pod level but can be overridden at the Container level:

- `runAsNonRoot`: Run the Container as a non-root user. It should be avoided as much as possible.
- `runAsUser`: The UID to run the entrypoint of the container process.
- `runAsGroup`: The GID to run the entrypoint of the container process.
- `fsGroup`: The GID to run the entrypoint of the container process.
- `appArmorProfile`: The AppArmor profile to apply to the container.
- `seccompProfile`: The seccomp profile to apply to the container.

####### Privileged Containers and privilege escalation

`Privileged` means that container user 0 (root) is directly mapped to the host user 0 (root).

Privilege escalation means that a process gains more privileges than its parent process.

Those are obviously security risks and should be avoided as much as possible.

####### Hands-on Security Contexts at the Container Level

Let's create a Pod with the following definition:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod2
spec:
  containers:
  - name: pod2
    image: busybox
    command:
    - sh
    - -c
    - sleep 1d
    securityContext: {}
```

Fairly simple, the Pod is running an Nginx container.

Create the Pod (`k apply -f pod2.yaml`) and exec into the container (`k exec -it pod2 -- sh`).

Inside the container, run the following command:

```bash
# Let's try to write in the root filesystem
sysctl kernel.hostname=attacker
```

We get a `sysctl: setting key "kernel.hostname": Read-only file system` error. The root filesystem is mounted as read-only.

Exit the container and update the Pod definition with a `privileged` directive. Update the `securityContext` section with the following:

```yaml
securityContext:
  privileged: true
```

Running again the command `sysctl kernel.hostname=attacker` should succeed, as the container is running in privileged mode.

Exit the container and update the Pod definition with an `allowPrivilegeEscalation` directive. Update the `securityContext` section with the following:

```yaml
securityContext:
  privileged: false
  allowPrivilegeEscalation: false
```

Run the following command to check the current capabilities:

```bash
cat /proc/1/status | grep NoNewPrivs
```

The output should be `NoNewPrivs: 1`. The `NoNewPrivs` flag is set, meaning that the container can't gain more privileges than its parent process.

Exit and delete the Pod.

### mTLS

- mTLS / Pod to Pod communication
- Service Meshes
- Scenarios
- Cilium

#### mTLS - Mutual TLS

- Mutual authentication
- Two-way (bilateral) authentication
- Two parties authenticating each other at the same time

##### K8s Pod to Pod communication

- By default, Pods can communicate with each other, thanks to the CNI plugin.
- No authentication or encryption by default.

Whenever an Ingress controller is ueed, it would stand as a TLS termination point, and the communication between the Ingress controller and the backend Pods would be unencrypted. In such scenarios, an attacker could intercept the communication between the Ingress controller and the backend Pods.

In order to secure the communication between Pods, mTLS can be used.

##### Service Meshes

- A dedicated infrastructure layer for handling service-to-service communication.
- Service Meshes can handle mTLS, service discovery, load balancing, etc.
- Examples: Istio, Linkerd, Consul Connect, Cilium, etc.
- It can be implemented as a sidecar container. The sidecar container would intercept all the traffic between the main container and the network. The sidecar container would handle the mTLS, service discovery, etc.

##### Hands-on Services Meshes

Let's create a simple Pod equiped with a sidecar container.

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: app
  name: app
spec:
  containers:
  - command:
    - sh
    - -c
    - ping google.com
    image: bash
    name: app
  - name: proxy
    image: ubuntu
    command:
    - sh
    - -c
    - apt update && apt install -y iptables && iptables -L && sleep 1d

  dnsPolicy: ClusterFirst
  restartPolicy: Always
```

Create the Pod (`k apply -f app.yaml`) and exec into the Pod.

Despite the fact the Pod seems to be running fine, the `proxy` fails to run the `iptables -L` command. This is due to the fact that the `proxy` container is not running as root.

Let's fix this by adding `capabilities` to the `proxy` container.

Update the Pod definition as follows:

```yaml
# Add this securityContext in the proxy container
securityContext:
    capabilities:
        add:
        - NET_ADMIN
```

Apply the changes (`k apply -f app.yaml`) then check the `iptables -L` command in the `proxy` container. It should now work.

####### Extra: Enable mTLS with Cilium

References:

- [Mutual Authentication (Beta)](https://docs.cilium.io/en/latest/network/servicemesh/mutual-authentication/mutual-authentication/#mutual-authentication-beta)
- [Mutual Authentication Example](https://docs.cilium.io/en/latest/network/servicemesh/mutual-authentication/mutual-authentication-example/#mutual-authentication-example)

In order to enable mTLS with Cilium, the following steps should be followed:

1. Connect to the cluster

    ```bash
    vagrant ssh vm1
    ```

2. Uninstall Cilium (if already installed)

    ```bash
    cilium uninstall
    ```

3. Install Cilium with mTLS enabled

    ```bash
    cilium install \
        --set authentication.mutual.spire.enabled=true \
        --set authentication.mutual.spire.install.enabled=true \
        --set authentication.mutual.spire.install.server.dataStorage.enabled=false
    ```

4. Verify the status of the Cilium agent and operator

    ```bash
    cilium status
    ```

Let's move on to a concrete example. Here we would use resources provided by the Cilium project.

Fetch them from the Cilium repository:

```bash
# Move to 16-mTLS directory
cd 16-mTLS
# Download the resources
curl -Lo extra-enable-mTLS-with-cilium/mutual-auth-example.yaml https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/kubernetes/servicemesh/mutual-auth-example.yaml
curl -Lo extra-enable-mTLS-with-cilium/cnp-without-mutual-auth.yaml https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/kubernetes/servicemesh/cnp-without-mutual-auth.yaml
```

Review them, then apply them:

```bash
k apply -f extra-enable-mTLS-with-cilium/mutual-auth-example.yaml
k apply -f extra-enable-mTLS-with-cilium/cnp-without-mutual-auth.yaml
```

Check the scenario is setup correctly:

```bash
k exec -it pod-worker -- curl -s -o /dev/null -w "%{http_code}" http://echo:8080/headers
# It should return 200
k exec -it pod-worker -- curl http://echo:8080/headers-1
# It should return Access Denied
```

As you may have noticed mTLS communication in this scenario is implemented through a SPIRE server.

Let's check the SPIRE server health:

```bash
k get all -n cilium-spire
# It should list all SPIRE related resources in a Ready/Running state
```

Run a health check on the SPIRE server:

```bash
k exec -n cilium-spire spire-server-0 -c spire-server -- /opt/spire/bin/spire-server healthcheck
# It should return Server is healthy
```

Have a look at the list of attested agents:

```bash
k exec -n cilium-spire spire-server-0 -c spire-server -- /opt/spire/bin/spire-server agent list
# It should list two agents
```

Let's verify SPIFFE IDs:

```bash
k exec -n cilium-spire spire-server-0 -c spire-server \
    -- /opt/spire/bin/spire-server entry show \
        -parentID spiffe://spiffe.cilium/ns/cilium-spire/sa/spire-agent
# It should list the SPIFFE ID of the cilium-agent
```

Fetch the Cilium Identity of the echo Pod:

```bash
IDENTITY_ID=$(k get cep -l app=echo -o=jsonpath='{.items[0].status.identity.id}')
echo $IDENTITY_ID
# It should return a number
```

Register the echo Pod with the SPIRE server:

```bash
k exec -n cilium-spire spire-server-0 -c spire-server \
    -- /opt/spire/bin/spire-server entry show \
        -spiffeID spiffe://spiffe.cilium/identity/$IDENTITY_ID
# It should return the entry in the SPIRE server
```

Now fetch the updated version of the CiliumNetworkPolicy:

```bash
curl -Lo extra-enable-mTLS-with-cilium/cnp-with-mutual-auth.yaml https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/kubernetes/servicemesh/cnp-with-mutual-auth.yaml
```

Remove the old CiliumNetworkPolicy and apply the new one:

```bash
k delete -f extra-enable-mTLS-with-cilium/cnp-without-mutual-auth.yaml
k apply -f extra-enable-mTLS-with-cilium/cnp-with-mutual-auth.yaml
```

Check the scenario is still working correctly:

```bash
k exec -it pod-worker -- curl -s -o /dev/null -w "%{http_code}" http://echo:8080/headers
# It should return 200
k exec -it pod-worker -- curl http://echo:8080/headers-1
# It should return Access Denied
```

Enable debug level logging for the Cilium agent:

```bash
cilium config set debug true
```

Check the logs of the Cilium agent located on the same worker node as the echo Pod:

```bash
k -n kube-system -c cilium-agent logs cilium-9pshw --timestamps=true | grep "Policy is requiring authentication\|Validating Server SNI\|Validated certificate\|Successfully authenticated"
```

Note that `cilium-9pshw` is the name of the Cilium agent Pod.

## Open Policy Agent

Open Policy Agent (OPA) is an extension that can be added to a Kubernetes cluster, that allow us to add custom policies to enforce security and compliance requirements.

- Request workflow and admission control
- Pod security standards
- Introduction to OPA and Gatekeeper

### Request Workflow and Admission Control

As a reminder, the request workflow in Kubernetes is as follows:

1. Any request is first authenticated. *Tell me who you are. I'll tell if you can come in...*
2. If the request is authenticated, it is authorized. *Tell me what you want to do. I'll tell if you can do it...*
3. If the request is authorized, it is admitted. *Before I proceed with your request, I need to validate and/or modify it...*

Most of the Security Enforcement in Kubernetes is done at the admission control level (step 3). OPA, Kyverno, Pod Security Standards, etc... come qwith their own admission controllers.

### Introduction to Pod Security Standards

Resources:

- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Auditing](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)

It define three different policies. They are cumulative and range from highly permissive to highly restrictive:

- **Prviliged**: Unrestricted policy, it allows for known privilege escalation.
- **Baseline**: Minimally restrictive policy which prevent known privilege escalations.
- **Restricted**: Highly restrictive policy, following current Pod hardening best practices.

#### Policy Instantiation

The policies definitions are decoupled from their instantiation. This allow a common understanding and acceptance of the policies, independently of their enforcement mechanism.

The [Pod Security Admission Controller](https://kubernetes.io/docs/concepts/security/pod-security-admission/) is a built-in mechanism that can enforce the Pod Security Standards at a namespace level. It is enabled by adding labels to the namespace.

At least a namespace must have the following labels to enforce the Pod Security Standards:

```yaml
# The per-mode level label indicates which policy level to apply for the mode.
#
# MODE must be one of `enforce`, `audit`, or `warn`.
# LEVEL must be one of `privileged`, `baseline`, or `restricted`.
pod-security.kubernetes.io/<MODE>: <LEVEL>

# Optional: per-mode version label that can be used to pin the policy to the
# version that shipped with a given Kubernetes minor version (for example v1.32).
#
# MODE must be one of `enforce`, `audit`, or `warn`.
# VERSION must be a valid Kubernetes minor version, or `latest`.
pod-security.kubernetes.io/<MODE>-version: <VERSION>
```

The `<MODE>` can be one of the followings:

- `enforce`: Policy violations will cause the Pod to be rejected.
- `audit`: Policy violations will be logged as an annotation to the event recorded in the audit log. The Pod will be admitted.
- `warn`: Policy violations will trigger a user-facing warning, but the Pod will be admitted.

The `<LEVEL>` can be one of `privileged`, `baseline`, or `restricted`.

The `<VERSION>` can be a valid Kubernetes minor version, or `latest`.

#### Hands-on Pod Security Standards

Lets create three namespaces with the different policies:

```bash
# Connect to the cluster
vagrant ssh vm1
# Move to the directory
cd /vagrant/formation/17-opa
# Create the namespaces
k apply -f privileged__ns.yaml
k apply -f baseline__ns.yaml
k apply -f restricted__ns.yaml
```

Now, we can create a Pod in each namespace:

```bash
# Create a Pod in each namespace
k -n privileged apply -f pod.yaml
k -n baseline apply -f pod.yaml
k -n restricted apply -f pod.yaml
```

All pods should be created successfully. Only for the `restricted` namespace, a warning should be displayed.

Delete the pods, then update the namespaces to enforce the policies:

```bash
# Delete the pods
k -n privileged delete pod nginx --grace-period=0 --force
k -n baseline delete pod nginx --grace-period=0 --force
k -n restricted delete pod nginx --grace-period=0 --force
# Keep only the restricted namespace
k delete ns privileged
k delete ns baseline
# Update the namespaces
k label ns restricted pod-security.kubernetes.io/warn-
k label ns restricted pod-security.kubernetes.io/warn-version-
k label ns restricted pod-security.kubernetes.io/audit=restricted
k label ns restricted pod-security.kubernetes.io/audit-version=v1.31
```

Now we need to update the kube-apiserver configuration to enable an audit policy, thus starting auditing the cluster. To do so, we need to mount a file (e.g. `audit-policy.yaml`) in the container.

```shell
sudo mkdir -p /etc/kubernetes/audit
sudo cp audit-policy.yaml /etc/kubernetes/audit/policy.yaml
sudo mkdir -p /var/log/kubernetes/audit
```

Then add a volume exposing this audit directories in the `kube-apiserver` Pod and mount them in the container. Edit the PodSpec directly.

```yaml
apiVersion: v1
kind: Pod
metadata:
# ...
  name: kube-apiserver
  namespace: kube-system
# ...
containers:
  - command:
    - kube-apiserver
    - --audit-policy-file=/etc/kubernetes/audit/policy.yaml
    - --audit-log-path=/var/log/kubernetes/audit/audit.log
# ...
    volumeMounts:
#...
    - mountPath: /etc/kubernetes/audit
      name: k8s-audit
      readOnly: true
    - mountPath: /var/log/kubernetes/audit
      name: k8s-audit-log
      readOnly: false
# ...
volumes:
# ...
- hostPath:
    path: /etc/kubernetes/audit
    type: DirectoryOrCreate
  name: k8s-audit
- hostPath:
    path: /var/log/kubernetes/audit
    type: DirectoryOrCreate
  name: k8s-audit-log
# ...
```

```bash
# Create the Pod
k -n restricted apply -f pod.yaml
```

The logs should show a warning about the Pod not being compliant with the Pod Security Standards.

TODO: Rework the audit policy file to concern only the Pod Security Standards.

TODO: Display a command to show the audit logs.

Remove the pod (`k -n restricted delete pod nginx --grace-period=0 --force`), then update the namespace to enforce the policy:

```bash
k label ns restricted pod-security.kubernetes.io/audit-
k label ns restricted pod-security.kubernetes.io/audit-version-
k label ns restricted pod-security.kubernetes.io/enforce=restricted
k label ns restricted pod-security.kubernetes.io/enforce-version=v1.31
```

Recreate the pod, it should be rejected.

### Introduction to OPA and Gatekeeper

- OPA (Open Policy Agent) is a general-purpose policy engine that can be used to enforce policies across the stack.
- Not Kubernetes-specific
- Offers easy implementation of policies (Rego language)
- Works with JSON/YAML
- In K8s, it uses Admission Controllers
- Unaware of concepts like Pods, Deployments, etc...
- Gatekeeper ease the use OPA in Kubernetes
- It provides CRDs

#### OPA - Gatekeeper CRDS

- `ConstraintTemplate`
- `Constraint`

#### Hands-on OPA - Gatekeeper

First, install OPA Gatekeeper. We use online resources:

```bash
curl -Lo install/gatekeeper.yaml  https://raw.githubusercontent.com/killer-sh/cks-course-environment/master/course-content/opa/gatekeeper.yaml
k apply -f install/gatekeeper.yaml
```

Let's create `DenyAll` policy:

```bash
# Fetch the template
curl -Lo deny-all/alwaysdeny_template.yaml https://raw.githubusercontent.com/killer-sh/cks-course-environment/refs/heads/master/course-content/opa/deny-all/alwaysdeny_template.yaml
# Fetch the constraint
curl -Lo deny-all/all_pod_always_deny.yaml https://raw.githubusercontent.com/killer-sh/cks-course-environment/refs/heads/master/course-content/opa/deny-all/all_pod_always_deny.yaml
k apply -f deny-all/alwaysdeny_template.yaml
k apply -f deny-all/all_pod_always_deny.yaml
```

Now, create a Pod:

```bash
k apply -f pod.yaml
```

The Pod should be rejected.

Now we want to enforce certain label on namespaces.

```bash
# Fetch the template
curl -Lo namespace-labels/k8srequiredlabels_template.yaml https://raw.githubusercontent.com/killer-sh/cks-course-environment/refs/heads/master/course-content/opa/namespace-labels/k8srequiredlabels_template.yaml
# Fetch the constraints
curl -Lo namespace-labels/all_ns_must_have_cks.yaml https://raw.githubusercontent.com/killer-sh/cks-course-environment/refs/heads/master/course-content/opa/namespace-labels/all_ns_must_have_cks.yaml
curl -Lo namespace-labels/all_pod_must_have_cks.yaml https://raw.githubusercontent.com/killer-sh/cks-course-environment/refs/heads/master/course-content/opa/namespace-labels/all_pod_must_have_cks.yaml
```

Let's create the Gatekeeper policy:

```bash
# Create the Gatekeeper policy template
k apply -f namespace-labels/k8srequiredlabels_template.yaml
# Create the Gatekeeper policy constraint
k apply -f namespace-labels/all_ns_must_have_cks.yaml
```

Check the CRDs:

```bash
k get crd
```

It should list the `k8srequiredlabels.constraints.gatekeeper.sh` CRD.

Now list those resources:

```bash
k get k8srequiredlabels
```

It should list the `ns-must-have-cks` constraint.

List thr current violations of the constraint by describing the constraint:

```bash
k describe k8srequiredlabels ns-must-have-cks
```

It should list the violations. Among them, the `default` namespace should be listed.

Let's fix the violation by adding the required label to the `default` namespace:

```bash
k label ns default cks=false
```

After a few seconds, the violation should disappear.

Now, let's create a new namespace:

```bash
k create ns test
```

The namespace should be rejected.

Update the constraint to enforce the presence of two labels instead of one:

```yaml
# Update in the file `namespace-labels/all_ns_must_have_cks.yaml`
# ...
  labels: ["cks", "team"]
```

Apply the updated constraint:

```bash
k apply -f namespace-labels/all_ns_must_have_cks.yaml
```

Try again to create the `test` namespace. It should be rejected, with a message indicating that the `team` label is also missing.

Create a new manifest for this namespace:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: test
  labels:
    cks: "true"
    team: "dev"
```

Use this manifest to create the namespace, it should be accepted.

Cleanup the resources:

```bash
k delete -f namespace-labels/all_ns_must_have_cks.yaml
k delete -f namespace-labels/k8srequiredlabels_template.yaml
k delete ns test
```

Let's move on to deploy constraints on deployments. First, fetch the resources:

```bash
# Fetch the template
curl -Lo deployment-replica-count/k8sminreplicacount_template.yaml https://raw.githubusercontent.com/killer-sh/cks-course-environment/refs/heads/master/course-content/opa/deployment-replica-count/k8sminreplicacount_template.yaml
# Fetch the constraints
curl -Lo deployment-replica-count/all_deployment_must_have_min_replicacount.yaml https://raw.githubusercontent.com/killer-sh/cks-course-environment/refs/heads/master/course-content/opa/deployment-replica-count/all_deployment_must_have_min_replicacount.yaml
```

Create the Gatekeeper policy:

```bash
# Create the Gatekeeper policy template
k apply -f deployment-replica-count/k8sminreplicacount_template.yaml
# Create the Gatekeeper policy constraint
k apply -f deployment-replica-count/all_deployment_must_have_min_replicacount.yaml
```

Let's create a deployment without enough replicas:

```bash
k create deployment nginx --image=nginx --replicas=1
```

It should be rejected.

Now, let's create a deployment with enough replicas:

```bash
k create deployment nginx --image=nginx --replicas=2
```

It should be accepted.

## Image Footprint

- Containers and Docker
- Reduce Image Size (Multi-Stage)
- Secure Images

### Containers and Docker

- Containers are a way to package software in a format that can run isolated on a shared operating system.
- Containers are lightweight because they don't need the extra load of a hypervisor, but run directly within the host machine's kernel.
- Containers are separated from each other and from the host machine to guarantee that they are isolated from each other, through the use of *kernel groups*.
- Containers are built from images that specify their precise contents. Images are built from layers that are stacked on top of each other. Each layer depends on the layer below it.
- Docker is a tool that automates the deployment of applications inside software containers. It uses a Dockerfile to describe how the layers are stacked.
- Dockerfiles are text files that contain the commands used to describe the layers in the image. Some of them would create layers, while others would create temporary images that would not increase the size of the final image.

### Reduce Image Size (Multi-Stage)

The idea behind multi-stage builds is to use multiple `FROM` statements in a single `Dockerfile`. Each `FROM` statement starts a new stage, and the final image is built from the last stage. The intermediate stages are not included in the final image, which reduces the size of the final image.

Thus, multi-stage builds are a way to reduce the size of the final image by using intermediate images that are not included in the final image. This is useful when you need to build an image that requires a lot of dependencies, but you don't want to include those dependencies in the final image.

#### Hands-on multi-stage build

First, we'll work with a simple example.

```shell
# Connect to the Vagrant VM
vagrant ssh vm1
# Move to the directory
cd 18-image-footprint/docker
# Build the image
sudo docker build -t app .
# Run the container
sudo docker run app
```

Check the image size with `sudo docker images`. It's pretty heavy. Let's try to reduce it with a multi-stage build.

Update the `Dockerfile` and add another `FROM` section:

```dockerfile
# ...
RUN CGO_ENABLED=0 go build app.go

FROM alpine
COPY --from=0 /app .

CMD ["./app"]
```

Now, build the image again:

```shell
sudo docker build -t app .
```

Check the image size again. It should be much smaller.

### Secure Images

- Keep images up to date: Regularly update the base image and dependencies.
- Use official images: Use official images from trusted sources. They are more likely to be secure and up to date.
- Use tagged images: Use tagged images to ensure that you are using a specific version of the image.
- Scan images: Use tools like Clair, Trivy, or Anchore to scan images for vulnerabilities.
- Use versioned packages: Use versioned packages to ensure that you are using a specific version of the package.
- Use minimal images: Use minimal images to reduce the attack surface.

#### Extra: analyse image with Trivy

Resources:

- [Installing Trivy](https://trivy.dev/latest/getting-started/installation/#debianubuntu-official)

##### Install Trivy

```shell
# Connect to the Vagrant VM
vagrant ssh vm1
# Install Trivy
sudo apt-get install wget gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy
```

Run Trivy to scan the image:

```shell
sudo trivy image app --ignore-unfixed --severity HIGH,CRITICAL --format json --output extra-trivy/app_docker-image__trivy.json
```

## Static Analysis of User Workloads

- What is static analysis?
- Manual approach
- Tools for Kubernetes and scenarios

### What is static analysis?

- Looks at source code and text files
- Check against rules
- Enforce rules

#### Static analysis rules

Examples:

- Always define resource requests and limits
- Pods shoud never use the default ServiceAccount

Rules depends on use case and company or project. Never store sensitive data plain in K8s/Docker files.

#### Static Analysis in CI/CD

The overall process would look like this:

1. Developer writes code
2. Code is committed then pushed to a repository
3. CI/CD pipeline is triggered to build the code, test it, and deploy it

Static analysis can be done in various stages of this process.

#### Manual approach

- Review code
- Check for common mistakes

#### Tools for Kubernetes and scenarios

##### [Kubesec](https://kubesec.io/)

Kubesec is a tool that can be used to perform security risk analysis on Kubernetes resources. It is opensource and opinianated. It checks a fixed set of rules (Security Best Practices). It run as:

- Binary
- Docker container
- Kubectl plugin
- Admission controller (kubesec-webhook)

Practical example:

```bash
# Connect to VM1
vagrant ssh vm1
# Move to the directory
cd 19-static-analysis/kubesec
# Create a pod manifest
k run nginx --image=nginx --dry-run=client -o yaml > pod.yaml
# Run kubesec through Docker
sudo docker run -i kubesec/kubesec:512c5e0 scan /dev/stdin < pod.yaml
```

Review the advices and fix the issues.

##### [Conftest - OPA](https://www.openpolicyagent.org/docs/latest/#conftest)

It is a Unit test framework for Kubernetes configurations. As for OPA, it uses Rego language.

Sources:

- [Conftest](https://www.conftest.dev/)
- [OPA](https://www.openpolicyagent.org/)
- [Rego](https://www.openpolicyagent.org/docs/latest/policy-language/)

Practical example:

```bash
# Connect to VM1
vagrant ssh vm1
# Move to the directory
cd 19-static-analysis/conftest/kubernetes
# Fetch the course resources from the repository
curl -Lo deploy.yaml https://raw.githubusercontent.com/killer-sh/cks-course-environment/refs/heads/master/course-content/supply-chain-security/static-analysis/conftest/kubernetes/deploy.yaml
mkdir policy
curl -Lo policy/deployment.rego https://raw.githubusercontent.com/killer-sh/cks-course-environment/refs/heads/master/course-content/supply-chain-security/static-analysis/conftest/kubernetes/policy/deployment.rego
echo 'sudo docker run --rm -v $(pwd):/project openpolicyagent/conftest test deploy.yaml' > run.sh
chmod +x run.sh
# Run the test
./run.sh
```

Review the advices and fix the issues.

Let's practice on a Dockerfile:

```bash
# Connect to VM1
vagrant ssh vm1
# Move to the directory
cd 19-static-analysis/conftest/docker
# Fetch the course resources from the repository
curl -Lo Dockerfile https://raw.githubusercontent.com/killer-sh/cks-course-environment/refs/heads/master/course-content/supply-chain-security/static-analysis/conftest/docker/Dockerfile
mkdir policy
curl -Lo policy/base.rego https://raw.githubusercontent.com/killer-sh/cks-course-environment/refs/heads/master/course-content/supply-chain-security/static-analysis/conftest/docker/policy/base.rego
curl -Lo policy/commands.rego https://raw.githubusercontent.com/killer-sh/cks-course-environment/refs/heads/master/course-content/supply-chain-security/static-analysis/conftest/docker/policy/commands.rego
echo 'sudo docker run --rm -v $(pwd):/project openpolicyagent/conftest test Dockerfile -' > run.sh
chmod +x run.sh
# Run the test
./run.sh
```

Review the advices and fix the issues.

## Scan images for known vulnerabilities

- Applications packaged within images may contain vulnerabilities.
- Those vulnerabilities can be exploited by attackers to compromise the system.
- They may live in different layers of the image.
- Scanning images for known vulnerabilities is a good practice to prevent security breaches. Scanning tools should be able to detect vulnerabilities in the base image, dependencies, and application code.
- Such tools make use of vulnerability databases:
  - [NVD](https://nvd.nist.gov/)
  - [Mitre](https://cve.mitre.org/)
  - etc.
- Vulnerabilities can be discovered at different stages:
  - At build time: before the image is pushed to the registry.
  - Within the registry: after the image is pushed.
  - At runtime: after the image is deployed.
  - At admission control: before the image is deployed.

### Scanning tools

#### [Clair](https://github.com/quay/clair)

- Open-source project for the static analysis of vulnerabilities in application containers.
- It can ingest vulnerabilities from different sources (databases like Mitre or NVD).
- It provides API

#### [Trivy](https://trivy.dev/latest/)

- Open-source project for scanning vulnerabilities in containers.
- It can scan images for vulnerabilities in the OS packages, application dependencies, and language-specific packages.

##### Run `trivy` with Docker

```bash
sudo docker run aquasec/trivy image nginx
```

It will fetch the latest database and scan the image for vulnerabilities.

Run the same command but filtering results with the `CRITICAL` severity:

```bash
sudo docker run aquasec/trivy --severity CRITICAL image nginx
```

Extra: Avoid fetching the database every time by mounting the cache directory:

```bash
sudo docker run -v $HOME/.cache/trivy:/root/.cache/trivy aquasec/trivy --severity CRITICAL image nginx
```

## Secure Supply Chain

- The supply chain - in this context - involve the process of delivering software from the developer to the end user.
- The supply chain is a critical part of the software development process, and it is important to ensure that the software is delivered securely.

### Private registries

- Similar to *public registries*, private registries are used to store and distribute software packages.
- Additionnaly, they offer more control over who can access the packages. Oftenly, they aren't accessible from outside the organization's network and require authentication to access a package.
- Within the kubernetes cluster, the authentication process would be handled by the container runtime. The crendentials must be provided in order to pull images.

#### Hands-on private registries

Here, we will list all image regitries used in the cluster. Then we'll see how to use digest for the kube-apiserver.

```bash
k get pods -A -o jsonpath='{.items[*].spec.containers[*].image}' | tr -s '[[:space:]]' '\n' | sort | uniq
```

This would return a list of images: some from recognized public registries, and some induced `docker.io` registry (which is a public registry). Within this list, we can see some images defined by their digest and others by their tag. As an example `kube-apiserver` is defined  by its tag.

Let's see with digest is associated to this tag:

```bash
k -n kube-system get pod kube-apiserver-cks-master -o jsonpath='{.status.containerStatuses[0].imageID}'
```

The `status` field contains the `imageID` field which is the digest of the image.

Replace with this value the definition of the `kube-apiserver` image in the `/etc/kubernetes/manifests` directory. After its restart the pod should use the digest instead of the tag.

Let's see now how to use OPA to whitelist registries. If needed run the following commands to install OPA in the cluster:

```bash
# Connect to VM1
vagrant ssh vm1
# Move to the right directory
cd 21-secure-supply-chain
# Fetch the OPA install resources
curl -Lo gatekeeper.yaml  https://raw.githubusercontent.com/killer-sh/cks-course-environment/master/course-content/opa/gatekeeper.yaml
k apply -f gatekeeper.yaml
```

Then, fetch the resources:

```bash
curl -Lo k8strustedimages_template.yaml https://raw.githubusercontent.com/killer-sh/cks-course-environment/refs/heads/master/course-content/supply-chain-security/secure-the-supply-chain/whitelist-registries/opa/k8strustedimages_template.yaml
curl -Lo all_pod_must_have_trusted_images.yaml https://raw.githubusercontent.com/killer-sh/cks-course-environment/refs/heads/master/course-content/supply-chain-security/secure-the-supply-chain/whitelist-registries/opa/all_pod_must_have_trusted_images.yaml
```

From the list of all images used in cluster computed earlier, keep  the different repositories and ensure each is allowed by editing the `k8strustedimages_template.yaml` just downloaded.

Apply the contraint template then the constraint. Check the number of violations:

```bash
k apply -f k8strustedimages_template.yaml
k apply -f all_pod_must_have_trusted_images.yaml
k describe k8strustedimages.constraints.gatekeeper.sh pod-trusted-images
```

There should be some violations.

Now try to create a simple pod:

```bash
k run nginx --image=nginx
```

It should be rejected! From now on, to create successfully a pod, the registry must be supplied, like `k run nginx --image=docker.io/nginx`.

### [ImagePolicyWebhook](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#imagepolicywebhook)

Basically, it is an admission controller that delegate to a webhook decisions during admission.

Let's enable it and observe how it works. Before ensure OPA is uninstalled:

```bash
k delete -f all_pod_must_have_trusted_images.yaml
k delete -f k8strustedimages_template.yaml
k delete -f gatekeeper.yaml
```

Once OPA has been cleaned up, edit `/etc/kubernetes/manifests/kube-apiserver.yaml` and update the list of enabled admission plugins by adding `ImagePolicyWebhook`.

The `kube-apiserver` pod should fail to restart, search for its logs whitin the directory `/var/log/pod/kube-system_kube-apiserver...`. It should complain about missing configuration. Read more about it in the [official documentation](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#imagereview-config-file-format).

Start by creating a file `/etc/kubernetes/admission/image-policy-webhook.conf` with the following content:

```yaml
imagePolicy:
  kubeConfigFile: /etc/kubernetes/admission/image-policy-webhook_kubeconfig.yaml
  # time in s to cache approval
  allowTTL: 50
  # time in s to cache denial
  denyTTL: 50
  # time in ms to wait between retries
  retryBackoff: 500
  # determines behavior if the webhook backend fails
  defaultAllow: false
```

Then create a file `/etc/kubernetes/admission/admission-control.conf` with the following content:

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
  - name: ImagePolicyWebhook
    path: /etc/kubernetes/admission/image-policy-webhook.conf
```

Then, create a file `/etc/kubernetes/admission/image-policy-webhook_kubeconfig.yaml` with the following content:

```yaml
apiVersion: v1
kind: Config
clusters:
- name: image-checker
  cluster:
    certificate-authority: /etc/kubernetes/admission/ca.pem    
    server: https://images.example.com/policy

contexts:
- context:
    cluster: image-checker
    user: api-server
  name: image-checker
current-context: image-checker
preferences: {}

users:
- name: api-server
  user:
    client-certificate: /etc/kubernetes/admission/cert.pem
    client-key: /etc/kubernetes/admission/key.pem
```

Finally, create the ca, cert and key files:

```bash
# Switch to su
sudo su
# Create the directory, then move to it
mkdir -p /etc/kubernetes/admission
cd /etc/kubernetes/admission
# Create the ca, cert and key files
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -subj "/CN=external-service" -days 10000 -out ca.pem
openssl genrsa -out key.pem 4096
openssl req -x509 -new -key key.pem -out cert.pem -subj "CN=image-policy-webhook"
# Leave su
exit
```

Then configure the `kube-apiserver` pod to use the new configuration: amongst the list of arguments, add `--admission-control-config-file=/etc/kubernetes/admission/admission-control.conf`.

From now on, the new admission controller `ImagePolicyWebhook` would forbid the creation of pods, since the remote service is unreachable and the default behavior is to deny. Try it, it should fail.

Update the default behavior to `true` to allow back pod creation.

## Behavioral Analytics at host and container level

- `syscall` and processes
- `strace` and `/proc`
- Tools and scenarios

### Kernel vs User Space

Quick reminder, a computer can be represented as a stack of layers, such as:

- Hardware
- Linux Kernel (Kernel Space)
- Syscall Interface (Kernel Space), like getpid(), reboot(), etc.
- Libraries (User Space), like `glibc`, `libxyz`, etc.
- Applications (User Space), like `Firefox`, `curl`, etc.

Applications can communicate with the syscall interface directly or through libraries.

The syscall interface relay the requests to the kernel, which then interacts with the hardware.

There are tools like `seccomp` or `apparmor` that operate between the User space and the Syscall Interface to filter, regulate or block requests.

This description is applicable to both the host and the containers. The difference is that containers share the same kernel as the host.

### System calls

There are many system calls, have a look at the [online version of `man syscall`](https://man7.org/linux/man-pages/man2/syscalls.2.html).

Basically, a system call is a request for a service made by an application to the operating system's kernel. It is a way for programs to interact with the operating system.

### `strace`

Tool that intercepts and logs system calls made by a process. It also log and display ssignals received by a process.

### Hands-on `strace`

```bash
strace ls /etc
```

It will display all the system calls made by the `ls` command.

```bash
strace -cw ls /
```

It will display a summary of the system calls made by the `ls` command. It will also display the count and time spent in each system call.

### `/proc`

- This directory contains information and connections to processes and kernel.
- It's a good place to learn how processes work.
- It's also importante for configuration and administrative tasks.
- It contains files that don't exist, yet you can access these.

### Hands-on `/proc`

Let's focus on `strace` of Kubernetes `etcd`. We want to:

1. List syscalls
2. Find open files
3. Read secret value

```bash
# Connect to VM1
vagrant ssh vm1
# Move to the right directory
cd 22-behavioral-analytics
# Ensure etcd is running
sudo crictl ps | grep etcd
# Get the PID of etcd
export ETCD_PID=$(sudo crictl inspect $(sudo crictl ps | grep etcd | cut -d' ' -f1) | jq '.info.pid')
# Lists syscalls
sudo strace -p $ETCD_PID -f -cw
```

After a few seconds, stop the `strace` command. It will display a summary of the system calls made by the `etcd` process.

Let's find open files:

```bash
sudo ls -lh /proc/$ETCD_PID/fd
```

This will list the files opened by the `etcd` process. Most are sockets, some are actual files. We can read the content of the file `/var/lib/etcd/member/snap/db`:

```bash
export SNAP_DB_ID=$(sudo ls -l /proc/$ETCD_PID/fd | grep "/var/lib/etcd/member/snap/db" | cut -d' ' -f9)
sudo tail /proc/$ETCD_PID/fd/$SNAP_DB_ID
```

It will display the content of the file. It contains data that aren't easily readable.

Now let's try to read the content of a secret:

```bash
# First let's create a secret
k apply -f credit-card_secret.yaml
# Install binutils to be able to use `strings`
sudo apt install -y binutils
# Find the name of the secret in the /var/lib/etcd/member/snap/db file
sudo cat /proc/$ETCD_PID/fd/$SNAP_DB_ID | strings | grep credit-card -A10 -B10
```

It should display some data related to the secret. We can even ensure we can see the secret value:

```bash
sudo cat /proc/$ETCD_PID/fd/$SNAP_DB_ID | strings | grep 1111222233334444 -A2 -B10
```

It should display the secret value, not even encoded...

Let's continue to explore the `/proc` directory:

```bash
# Create an Apache pod with a secret.
k apply -f apache_pod.yaml
# List environment variables of the Apache pod, ensure $SECRET is present
k exec apache -- env | grep SECRET
```

Now, let's find where the Apache process is running:

```bash
k get pod apache -o jsonpath='{.spec.nodeName}'
```

Then, connect to the node and find the PID of the Apache process:

```bash
# Connect to the node, adapt the vm name
vagrant ssh vm2
# Move to the right directory
cd 22-behavioral-analytics
# Get the PID of the Apache process
export APACHE_PID=$(sudo crictl inspect $(sudo crictl ps | grep apache | cut -d' ' -f1) | jq '.info.pid')
```

We'll use `pstree` to describe the whole hierarchy of the apache process, running in a container:

```bash
sudo pstree -p $APACHE_PID
```

It should display a hierarchy of processes composing the Apache process.

Let's display the `proc` description of the Apache process:

```bash
sudo ls -lh --color /proc/$APACHE_PID
```

Amongst the pseudo-files and directories, we can find the `environ` file, which contains the environment variables of the process. Let's see if it contains the $SECRET variable:

```bash
sudo cat /proc/$APACHE_PID/environ | strings | grep SECRET
```

It should display the value of the $SECRET variable, in plain sight!!!

#### Extra: get the Apache secret value without `sudo`

We saw how to get the secret value from the Apache process, but we used `sudo` to access the `/proc` directory. Let's see how to do it without `sudo`.

The trick is to start a *debug* pod on the node, then use `nsenter` to enter the Apache process namespace.

We need still need to get the node where the Apache pod has been scheduled:

```bash
# Connect to VM1
vagrant ssh vm1
# Move to the right directory
cd 22-behavioral-analytics
# Get the node name
export APACHE_NODE_NAME=$(k get pod apache -o jsonpath='{.spec.nodeName}')
```

Then, create a debug pod on the node:

```bash
k debug nodes/$APACHE_NODE_NAME --image=debian -it -- bash
```

The interactive shell should be started as root... Now let's `chroot` to the `/host` directory:

```bash
chroot /host bash
```

From now on, we are `root` on the host filesystem. We may proceed like before but without `sudo`:

```bash
export APACHE_PID=$(crictl inspect $(crictl ps | grep apache | cut -d' ' -f1) | jq '.info.pid')
cat /proc/$APACHE_PID/environ | strings | grep SECRET
```

It should display the secret value.

This emphasizes the importance of securing the access to the kubernetes API and **NEVER** allow `debug` pods on nodes. It might be handled with the use of RBAC.

### [Falco](https://falco.org/)

- Cloud-native runtime security (CNCF)
- Provides different areas of expertise:
  - ACCESS:
      Deep kernel tracing built on the Linux kernel
  - ASSERT:
      Describe security rules against a system (+default ones)
      Detect unwanted behaviour
  - ACTION
      Automated respond to a security violations

### Hands-on Falco

TODO
