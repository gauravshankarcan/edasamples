# Decision Environment with community.aws

A **Decision Environment (DE)** is to `ansible-rulebook` what an
**Execution Environment (EE)** is to `ansible-playbook`. It is an OCI
container image that contains:

- `ansible-rulebook` binary
- Event source plugins (from collections)
- Python dependencies for sources
- Collections needed by `run_playbook` actions

> **Key difference**: EEs run your playbooks. DEs run your rulebooks.
> Job Templates use EEs. Rulebook Activations use DEs.

## Contents

| File | Purpose |
|---|---|
| `Containerfile` | OCI build file (use with `podman build`) |
| `execution-environment.yml` | ansible-builder config (alternative to Containerfile) |
| `requirements.yml` | Ansible collections to install (`community.aws`, `ansible.eda`, etc.) |
| `requirements.txt` | Python packages (boto3, aiohttp, etc.) |
| `bindep.txt` | System packages (git, curl, etc.) |
| `build.sh` | Automated build + push to OCP ImageStream |

## Build Methods

### Method 1: podman direct (recommended for development)

```bash
# Build
podman build -t eda-community-de:latest -f Containerfile .

# Verify
podman run --rm eda-community-de:latest ansible-rulebook --version
podman run --rm eda-community-de:latest ansible-galaxy collection list
```

### Method 2: ansible-builder (recommended for CI/CD)

```bash
pip install ansible-builder
ansible-builder build \
  -t eda-community-de:latest \
  --container-runtime podman \
  -v 3
```

### Method 3: build_de.yml (full pipeline — build + push + register in AAP)

```bash
export KUBECONFIG=/tmp/kubeconfig-eda-session
export AAP_BASE="https://aap-aap.apps-crc.testing"
export AAP_PASS="<your-aap-password>"
ansible-playbook decision-environment/build_de.yml
```

## What build.sh Does

1. Builds the DE image using `podman build`
2. Verifies `ansible-rulebook` and `community.aws` are present
3. Creates an OCP **ImageStream** `eda-community-de` in the `aap` namespace
4. Pushes the image to the OCP internal registry
5. Registers the DE in **AAP EDA Controller** as `EDA-Community-DE`

## Best Practices for DE Development

### 1. Keep DEs minimal
Only include collections needed by **event sources** and `run_playbook` actions.
If you use `run_job_template`, the target collection goes in the EE instead.

### 2. Pin collection versions
```yaml
# requirements.yml — use specific versions in production
collections:
  - name: community.aws
    version: "8.2.0"   # ← Pinned, not ">=8.0.0"
```

### 3. Tag images with semantic versions + git SHA
```bash
GIT_SHA=$(git rev-parse --short HEAD)
podman build -t "eda-community-de:1.2.0-$GIT_SHA" .
podman tag "eda-community-de:1.2.0-$GIT_SHA" "eda-community-de:latest"
```

### 4. Test locally before pushing
```bash
# Run a rulebook in the DE image to test it works
podman run --rm \
  -v $(pwd)/../samples:/rulebooks:ro \
  eda-community-de:latest \
  ansible-rulebook \
    --rulebook /rulebooks/rulebook.yml \
    --inventory /rulebooks/inventory/hosts.yml \
    --print-events
```

### 5. Use multi-stage builds for smaller images
```dockerfile
# Stage 1: Build
FROM de-supported-rhel9:latest AS builder
COPY requirements.yml /tmp/
RUN ansible-galaxy collection install -r /tmp/requirements.yml

# Stage 2: Runtime (copy only what's needed)
FROM de-minimal-rhel9:latest
COPY --from=builder /usr/share/ansible/collections /usr/share/ansible/collections
```

## Verifying community.aws Installation

```bash
# List installed collection
podman run --rm eda-community-de:latest ansible-galaxy collection list community.aws

# Check a specific module is available
podman run --rm eda-community-de:latest \
  ansible-doc community.aws.ec2_instance | head -20

# Run a quick test
podman run --rm \
  -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
  -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
  -e AWS_DEFAULT_REGION="us-east-1" \
  eda-community-de:latest \
  ansible -m community.aws.ec2_instance_info \
    -a "region=us-east-1 filters={tag:Environment:eda-test}" \
    localhost
```

## OCP ImageStream Reference

After running `build.sh`, the image is available in OCP as:

```
# External reference (from outside cluster)
image-registry-openshift-image-registry.apps-crc.testing/aap/eda-community-de:latest

# Internal reference (for pods/AAP inside cluster)
image-registry.openshift-image-registry.svc:5000/aap/eda-community-de:latest
```

Use the **internal reference** when registering the DE in AAP EDA Controller,
since AAP pods run inside the cluster and can access the internal registry
directly.
