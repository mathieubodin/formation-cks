# Static Analysis of User Workloads

- What is static analysis?
- Manual approach
- Tools for Kubernetes and scenarios

## What is static analysis?

- Looks at source code and text files
- Check against rules
- Enforce rules

### Static analysis rules

Examples:

- Always define resource requests and limits
- Pods shoud never use the default ServiceAccount

Rules depends on use case and company or project. Never store sensitive data plain in K8s/Docker files.

### Static Analysis in CI/CD

The overall process would look like this:

1. Developer writes code
2. Code is committed then pushed to a repository
3. CI/CD pipeline is triggered to build the code, test it, and deploy it

Static analysis can be done in various stages of this process.

### Manual approach

- Review code
- Check for common mistakes

### Tools for Kubernetes and scenarios

#### [Kubesec](https://kubesec.io/)

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

#### [Conftest - OPA](https://www.openpolicyagent.org/docs/latest/#conftest)

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
