# Open Policy Agent

Open Policy Agent (OPA) is an extension that can be added to a Kubernetes cluster, that allow us to add custom policies to enforce security and compliance requirements.

- Request workflow and admission control
- Pod security standards
- Introduction to OPA and Gatekeeper

## Request Workflow and Admission Control

As a reminder, the request workflow in Kubernetes is as follows:

1. Any request is first authenticated. *Tell me who you are. I'll tell if you can come in...*
2. If the request is authenticated, it is authorized. *Tell me what you want to do. I'll tell if you can do it...*
3. If the request is authorized, it is admitted. *Before I proceed with your request, I need to validate and/or modify it...*

Most of the Security Enforcement in Kubernetes is done at the admission control level (step 3). OPA, Kyverno, Pod Security Standards, etc... come qwith their own admission controllers.

## Introduction to Pod Security Standards

Resources:

- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Auditing](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)

It define three different policies. They are cumulative and range from highly permissive to highly restrictive:

- **Prviliged**: Unrestricted policy, it allows for known privilege escalation.
- **Baseline**: Minimally restrictive policy which prevent known privilege escalations.
- **Restricted**: Highly restrictive policy, following current Pod hardening best practices.

### Policy Instantiation

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

### Hands-on Pod Security Standards

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

## Introduction to OPA and Gatekeeper

- OPA (Open Policy Agent) is a general-purpose policy engine that can be used to enforce policies across the stack.
- Not Kubernetes-specific
- Offers easy implementation of policies (Rego language)
- Works with JSON/YAML
- In K8s, it uses Admission Controllers
- Unaware of concepts like Pods, Deployments, etc...
- Gatekeeper ease the use OPA in Kubernetes
- It provides CRDs

### OPA - Gatekeeper CRDS

- `ConstraintTemplate`
- `Constraint`

### Hands-on OPA - Gatekeeper

First, install OPA Gatekeeper. We use 

```bash
curl -Lo install/gatekeeper.yaml  https://raw.githubusercontent.com/killer-sh/cks-course-environment/master/course-content/opa/gatekeeper.yaml
```

Let's create `DenyAll` policy:

```bash
# Fetch the template
curl -Lo deny-all/alwaysdeny_template.yaml https://raw.githubusercontent.com/killer-sh/cks-course-environment/refs/heads/master/course-content/opa/deny-all/alwaysdeny_template.yaml
# Fetch the constraint
curl -Lo deny-all/all_pod_always_deny.yaml https://raw.githubusercontent.com/killer-sh/cks-course-environment/refs/heads/master/course-content/opa/deny-all/all_pod_always_deny.yaml
```

