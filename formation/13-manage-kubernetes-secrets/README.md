# Manage Kubernetes Secrets

Here we will create a simple pod, two secrets `secret1` - mounted in `pod` as a file - and `secret2` - mounted in `pod` as an environment variable.

## Create the secrets

```shell
k create secret generic secret1 --from-literal=authentication=secretpassword
k create secret generic secret2 --from-literal=login=secretlogin
```

## Create the pod

```shell
k run pod --image=nginx --dry-run=client -o yaml > pod.yaml
```

Edit the `pod.yaml` file and add the secrets support.

## Check secrets in `ectd`

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

## Encrypt the secrets in `etcd`

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
