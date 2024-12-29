# CKS

## Resources

- [Kubernetes CKS Full Course Theory + Practice + Browser Scenarios](https://www.youtube.com/watch?v=d9xfB5qaOfg)
- [Kubernetes Security Best Practices - Ian Lewis, Google](https://youtu.be/wqsUfvRyYpw?si=vrIh_1r18fpo8i3K)
- [Martin White - Consistent Security Controls through CIS Benchmarks](https://youtu.be/53-v3stlnCo?si=-ulNwAyFuU55I9P-)
- [OpenSSL Certificate Authority](https://jamielinux.com/docs/openssl-certificate-authority)

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

#### Node Metadata protection

- Metadata API available on virtual machines spun up in cloud providers
- Metadata API can be used to get sensitive information
- Pods on worker nodes can access the metadata API
- Metadata API access should be restricted to pods that need it, through Network Policies for example.

#### Use CIS Benchmarks to review security configurations

- CIS Benchmarks are a set of best practices for securing a system
- CIS Benchmarks are available for Kubernetes

##### Hands-on CIS Benchmarks in action

We'll use `kube-bench` to check the cluster against the CIS benchmarks. It will be run on the master node from within a container.

```shell
sudo docker run --pid=host -v /etc:/etc:ro -v /var:/var:ro -t docker.io/aquasec/kube-bench:latest --version 1.31
```

This can be done also on the worker node.

#### Verify platform binaries

- Verify the checksum of the binaries with hashes, which is a *finger print*.
- The process is quite simple: download the binary, download the hash, and compare the latter with the one you would compute for the binary.

##### Hands-on Verify platform binaries

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

### Cluster Hardening

- RBAC
- ServiceAccounts
- Restrict API access
- Upgrade Kubernetes

#### RBAC

- Role Based Access Control
- Define roles and bind them to users
- Define what is allowed, otherwise it is denied. Permissions are *additive*.
  - Deny is not possible, only *"whitelisting"*
- Enforce the principle of least privilege

The following table shows the permissions available and where they are applied:

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

Reminder:

1. A set of permissions (Role or ClusterRole) **can** be granted to an identity at a namespace level (with RoleBinding). A ClusterRole **can** also be granted to an identity at a cluster level (with ClusterRoleBinding).
2. When a ClusterRole is granted to an identity through a ClusterRoleBinding, the permissions are granted **across all namespaces, now and in the future**.
3. A Role **can't** be granted to an identity at a cluster level (with ClusterRoleBinding).

##### Hands-on RBAC

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

#### Accounts

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

##### Hands-on Accounts

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

#### Service Accounts

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

##### Hands-on Service Accounts

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

#### Restrict API access

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

##### Hands-on Restrict API access

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

##### Extra: expose the API server to the outside with Ingress

```shell

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --create-namespace --namespace ingress-nginx --set controller.kind=DaemonSet --set controller.service.enabled=false --set controller.hostNetwork=true --set controller.admissionWebhooks.service.enabled=true --set controller.allow-snippet-annotations=true
```
