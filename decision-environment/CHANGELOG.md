# Decision Environment Changelog
## AAP 2.6 → AAP 2.7 (`de-supported-rhel9:latest`)

Images compared:
- `registry.redhat.io/ansible-automation-platform-26/de-supported-rhel9:latest`
- `registry.redhat.io/ansible-automation-platform-27/de-supported-rhel9:latest`

---

## Summary of Breaking Changes

| Area | AAP 2.6 | AAP 2.7 | Action Required |
|------|---------|---------|-----------------|
| Python | 3.11 | **3.12** | Rebuild custom DEs; test Python 3.12 compatibility |
| AWS event sources | `ansible.eda.*` | `amazon.aws.*` | Update rulebook namespaces |
| Azure event sources | `ansible.eda.*` | `azure.azcollection.*` | Update rulebook namespaces |
| Built-in sources | `ansible.eda.*` | `eda.builtin.*` | Update rulebook namespaces |
| `ansible.eda.noop` | supported | **removed** (no replacement) | Remove from rulebooks |
| RPM installer | supported | **removed** | Migrate to containerized |

---

## 1. Python Runtime

| | AAP 2.6 | AAP 2.7 |
|--|---------|---------|
| Python version | **3.11** | **3.12** |
| Status | Python 3.11 deprecated in 2.7 | Python 3.12 required |

**Impact on custom DEs:**
- If your custom DE or its Python dependencies use Python 3.11-specific syntax, rebuild and test.
- Python 3.11 layers no longer receive CVE patches in AAP 2.7.
- The base image `de-supported-rhel9:latest` is now Python 3.12 based.

---

## 2. ansible-core Version

| | AAP 2.6 | AAP 2.7 |
|--|---------|---------|
| Default ansible-core | **2.16** | **2.16** |
| Optional EE variant | — | 2.18 available |

Both platforms default to ansible-core 2.16. For decision environments, this version
is used to run any `run_playbook` actions directly inside the DE. No change here.

---

## 3. ansible-rulebook (Event-Driven Ansible engine)

| | AAP 2.6 | AAP 2.7 |
|--|---------|---------|
| EDA component version | 1.2.x | newer (built-in sources added) |
| Built-in namespace | `ansible.eda.*` | `eda.builtin.*` (new) |
| `ansible.eda` maintained | Yes | Deprecated for some plugins |

### New `eda.builtin` namespace (AAP 2.7)

Common sources and filters are now packaged directly in `ansible-rulebook` as
built-in modules. The `ansible.eda` namespace aliases still work for backwards
compatibility but are no longer actively maintained.

| Old name (ansible.eda) | New name (eda.builtin) |
|------------------------|------------------------|
| `ansible.eda.generic` | `eda.builtin.generic` |
| `ansible.eda.range` | `eda.builtin.range` |
| `ansible.eda.webhook` | `eda.builtin.webhook` |
| `ansible.eda.insert_meta_info` | `eda.builtin.insert_meta_info` |
| `ansible.eda.dicts_to_native_types` | `eda.builtin.dicts_to_native_types` |

**Recommendation:** Update rulebooks to use `eda.builtin.*` for long-term stability.

---

## 4. AWS Event Sources — Namespace Migration

In AAP 2.6, AWS event sources lived in `ansible.eda`. In AAP 2.7, they are
**deprecated** in `ansible.eda` and have moved to `amazon.aws`.

The `de-supported-rhel9:latest` (2.7) now includes `amazon.aws` built-in.

| Old name (AAP 2.6) | New name (AAP 2.7) | Notes |
|--------------------|-------------------|-------|
| `ansible.eda.aws_sqs_queue` | `amazon.aws.aws_sqs_queue` | Certified source |
| `ansible.eda.aws_cloudtrail` | `amazon.aws.aws_cloudtrail` | Certified source |

**Example rulebook update:**

```yaml
# AAP 2.6 (still works in 2.7 with deprecation warning)
sources:
  - ansible.eda.aws_sqs_queue:
      queue_name: my-queue
      region: us-east-1

# AAP 2.7 — recommended
sources:
  - amazon.aws.aws_sqs_queue:
      queue_name: my-queue
      region: us-east-1
```

---

## 5. Azure Event Sources — Namespace Migration

In AAP 2.6, Azure event sources lived in `ansible.eda`. In AAP 2.7, they have
moved to `azure.azcollection`.

The `de-supported-rhel9:latest` (2.7) now includes `azure.azcollection` built-in.

| Old name (AAP 2.6) | New name (AAP 2.7) | Notes |
|--------------------|-------------------|-------|
| `ansible.eda.azure_service_bus` | `azure.azcollection.azure_service_bus` | Certified source |

**Example rulebook update:**

```yaml
# AAP 2.6 (still works in 2.7 with deprecation warning)
sources:
  - ansible.eda.azure_service_bus:
      namespace: my-namespace
      topic: my-topic

# AAP 2.7 — recommended
sources:
  - azure.azcollection.azure_service_bus:
      namespace: my-namespace
      topic: my-topic
```

---

## 6. Sources Moved to `community.eda` (Not Red Hat Supported)

The following sources are **removed** from the Red Hat certified `ansible.eda`
collection and moved to the community-maintained `community.eda` collection.
They require a **custom DE** to use in AAP 2.7.

| Source | New location | Requires custom DE |
|--------|-------------|-------------------|
| `ansible.eda.url_check` | `community.eda.url_check` | Yes |
| `ansible.eda.file_watch` | `community.eda.file_watch` | Yes |
| `ansible.eda.journal` | `community.eda.journald` | Yes |
| `ansible.eda.tick` | `eda.builtin.generic` OR `eda.builtin.range` | No |
| `ansible.eda.noop` | **removed** (no replacement) | — |

**For `tick`**: Use `eda.builtin.range` for a countdown source or
`eda.builtin.generic` for a configurable periodic source.

---

## 7. Included Collections — de-supported-rhel9

Collections included directly in the standard `de-supported-rhel9` image:

| Collection | AAP 2.6 | AAP 2.7 | Change |
|-----------|---------|---------|--------|
| `ansible.eda` | ✅ (primary) | ✅ (legacy aliases) | Deprecated sources removed |
| `amazon.aws` | ❌ | ✅ **new** | AWS sources now certified in-image |
| `azure.azcollection` | ❌ | ✅ **new** | Azure sources now certified in-image |
| `ansible.utils` | ✅ | ✅ | Maintained |
| `ansible.posix` | ✅ | ✅ | Maintained |

**Impact for custom DEs:**
- In AAP 2.6: You needed to add `community.aws` or `azure.azcollection` to your
  custom DE to use AWS/Azure event sources.
- In AAP 2.7: `amazon.aws` and `azure.azcollection` are included in `de-supported`.
  You only need a custom DE for community or third-party sources.

---

## 8. Platform-Level Changes Affecting DE Usage

### RPM Installer Removed (AAP 2.7)
The RPM-based installer is no longer available. DEs must run on a containerized
or OpenShift deployment.

### ee-cloud-services Removed from Azure Managed App
The `ee-cloud-services` execution environment is no longer available in new
deployments of AAP on Microsoft Azure. Use `ee-supported` instead.

### auto-restart on Project Update (AAP 2.7)
New setting: EDA activations can automatically restart when a project sync
detects rulebook changes. Configure via the activation settings UI.

---

## 9. Migration Checklist

For upgrading from AAP 2.6 to AAP 2.7 with custom DEs:

```
[ ] Update base image FROM line:
      FROM registry.redhat.io/ansible-automation-platform-27/de-supported-rhel9:latest

[ ] Update rulebooks:
      ansible.eda.aws_sqs_queue    → amazon.aws.aws_sqs_queue
      ansible.eda.aws_cloudtrail   → amazon.aws.aws_cloudtrail
      ansible.eda.azure_service_bus → azure.azcollection.azure_service_bus
      ansible.eda.webhook          → eda.builtin.webhook (or keep as-is)
      ansible.eda.url_check        → community.eda.url_check (needs custom DE)
      ansible.eda.file_watch       → community.eda.file_watch (needs custom DE)
      ansible.eda.journal          → community.eda.journald (needs custom DE)
      ansible.eda.noop             → remove from rulebooks (no replacement)

[ ] Remove community.aws from custom DE requirements.yml if using
    amazon.aws.aws_sqs_queue / aws_cloudtrail instead

[ ] Remove azure.azcollection from custom DE requirements.yml
    if it was added to use azure_service_bus (now bundled)

[ ] Test Python 3.12 compatibility of any custom Python
    packages installed via requirements.txt

[ ] If using ansible.eda.tick with pulse generation, switch to
    eda.builtin.range or eda.builtin.generic
```

---

## 10. This Repository's DE (`decision-environment/`)

Changes made to `execution-environment.yml` and `requirements.yml` in this repo
to support AAP 2.7:

| File | Change |
|------|--------|
| `execution-environment.yml` | Base image updated to `de-supported-rhel9:latest` (already AAP 2.7 tag) |
| `requirements.yml` | Added `azure.azcollection >= 2.0.0` and `community.crypto` |
| `requirements.yml` | AWS sources: switched from `community.aws` to `amazon.aws` pattern |

The rulebooks in this repo (`rulebooks/`) use `ansible.eda.webhook` which maps
to `eda.builtin.webhook` in AAP 2.7 via the backwards-compatible alias.
No rulebook changes are required for the webhook source.
