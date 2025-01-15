# Container Runtime Sandboxes

- *Container are not VMS* - they are not isolated from the host system. They are isolated from each other, but not from the host system. They share the same kernel as the host system.
- Since they share the same kernel as the host, an attacker may use this to their advantage to break out of the container and access the host system.
- To mitigate this, we can use container runtime sandboxes. These helps to reduce the attack surface.

## Containers and system calls

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

### Hands on: Contact the linux kernel from a container

Run a simple container, then exec into it:

```bash
k run pod --image=alpine
k exec -it pod -- uname -r
```

It should return the kernel version of the host system.

## OCI: Open Container Initiative

- Linux Foundation project to design open standards for virtualization.
- It defines a specification for container runtime, image format and distribution.
- It also supply a reference implementation called `runc`.
- `kubelet` may use any OCI compliant runtime, only one can be used at a time. It is defined in the `kubelet` configuration file, through the `--container-runtime` and `--container-runtime-endpoint` flags.

## kata containers

- It is based on kightweight VMs with individual kernels.
- It provide a strong separation layer
- Runs every container in its own private VM.
- By default, it uses `QEMU` to run the VMs.

## gVisor

- It is a user-space kernel, that intercepts system calls and manages them.
- Another layer of isolation between the container and the host system.
- It is **NOT** based on VMs.
- It simulates kernel syscalls with limited functionality, it is written in Go.
- It runs in userspace separated from the host kernel.
- The runtime is called `runsc`.

### Hands on: RuntimeClass

Create and use a `RuntimeClass` to use `gVisor` as the runtime for a pod.

