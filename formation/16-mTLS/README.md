# mTLS

- mTLS / Pod to Pod communication
- Service Meshes
- Scenarios
- Cilium

## mTLS - Mutual TLS

- Mutual authentication
- Two-way (bilateral) authentication
- Two parties authenticating each other at the same time

### K8s Pod to Pod communication

- By default, Pods can communicate with each other, thanks to the CNI plugin.
- No authentication or encryption by default.

Whenever an Ingress controller is ueed, it would stand as a TLS termination point, and the communication between the Ingress controller and the backend Pods would be unencrypted. In such scenarios, an attacker could intercept the communication between the Ingress controller and the backend Pods.

In order to secure the communication between Pods, mTLS can be used.

### Service Meshes

- A dedicated infrastructure layer for handling service-to-service communication.
- Service Meshes can handle mTLS, service discovery, load balancing, etc.
- Examples: Istio, Linkerd, Consul Connect, Cilium, etc.
- It can be implemented as a sidecar container. The sidecar container would intercept all the traffic between the main container and the network. The sidecar container would handle the mTLS, service discovery, etc.

### Hands-on Services Meshes

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

#### Extra: Enable mTLS with Cilium

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
