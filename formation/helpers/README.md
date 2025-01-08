# Helpers

This directory contains helper functions that are used in the formation package.

Each function may be used from the command line - within the virtual machine - by running the through the following command:

```bash
bash helpers/<function_name>.sh
```

The functions are organized into the following files:

- `helm__install.sh`: installs the helm package manager locally.
- `kubectl__install.sh`: installs the kubectl command line tool locally. Note the configuration still needs to be done.
- `kubernetes_controlplane__install.sh`: installs the kubernetes control plane locally. Note that workers still need to be added.
- `kubernetes_worker__install.sh`: installs a kubernetes worker locally. Note that it need the control plane to be installed and running.
- `kubernetes_worker-gvisor__install.sh`: installs a kubernetes worker with gvisor support locally. Note that it need the control plane to be installed and running. It would also need a RuntimeClass to be created.
- `pki__initialize.sh`: initializes the public key infrastructure locally.
- `ingress-controller__install.sh`: installs the ingress controller locally. Note that the ingress controller still needs to be configured.
- `ingress-controller__configure.sh`: configures the ingress controller locally.
