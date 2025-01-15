# OS Level Security Domains

- Security Contexts

## Security Contexts

- Define privilege and access control for a Pod or Container.
  - userID and groupID
  - Run privileged or unprivileged
  - Linux capabilities
  - etc...
- Security Contexts can be defined at the Pod or Container level. At the Pod level, the security context applies to all Containers in the Pod. At the Container level, the security context is specific to the Container.

### Security Contexts at the Pod Level

The followings are rules of thumb for defining security contexts at the Pod level.

It must define at least the following:

- `runAsNonRoot`: Run the Pod as a non-root user. Kubelet will not run the Pod as root.
- `runAsUser`: The UID to run the entrypoint of the container process.
- `fsGroup`: The GID to run the entrypoint of the container process.
- `runAsGroup`: The GID to run the entrypoint of the container process.

It should define the following:

- `appArmorProfile`: The AppArmor profile to apply to the container.
- `seccompProfile`: The seccomp profile to apply to the container.

#### Hands-on Security Contexts at the Pod Level

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

#### Extra: work with `fsGroup`

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

### Security Contexts at the Container Level

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

#### Privileged Containers and privilege escalation

`Privileged` means that container user 0 (root) is directly mapped to the host user 0 (root).

Privilege escalation means that a process gains more privileges than its parent process.

Those are obviously security risks and should be avoided as much as possible.

#### Hands-on Security Contexts at the Container Level

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
