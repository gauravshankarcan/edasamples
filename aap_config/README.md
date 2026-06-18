# AAP Configuration as Code

Configures the entire AAP environment for EDA samples using the
[`infra.aap_configuration`](https://github.com/redhat-cop/infra.aap_configuration)
collection and its `dispatch` role.

## What gets configured

### AAP Controller
| Object | Name |
|--------|------|
| Organization | Default |
| Credential | EDA-AWS-Credential (Amazon Web Services) |
| Inventory | EDA-Sample-Inventory (static, localhost) |
| Inventory | EDA-AWS-Dynamic-Inventory (EC2 dynamic) |
| Inventory Source | EDA-AWS-EC2-Source |
| Project | EDA-Samples-Project (GitHub) |
| Job Template | EDA-Sample-Webhook-Handler |
| Job Template | EDA-Param-Deploy-Service |
| Job Template | EDA-Limit-OS-Patching |
| Job Template | EDA-Requestor-Handler |
| Job Template | EDA-Regex-Demo |

### EDA Controller
| Object | Name |
|--------|------|
| Decision Environment | EDA-Community-DE |
| EDA Credential | EDA-AAP-Controller-Credential |
| EDA Project | EDA-Samples |
| Activation | sample-webhook-activation |
| Activation | eda-param-samples-activation |
| Activation | eda-limit-jobs-activation |
| Activation | eda-requestor-activation |
| Activation | eda-regex-demo-activation |

## File structure

```
aap_config/
├── configure_aap.yml        ← main playbook (2 plays: dispatch + OCP Routes)
├── requirements.yml         ← collection dependencies
├── vault-example.yml        ← template for secrets (copy → vault.yml)
└── vars/
    ├── auth.yml             ← connection variables (references vault vars)
    ├── controller_config.yml ← all Controller objects
    └── eda_config.yml       ← all EDA objects
```

## Quick start

### 1. Install collections

```bash
ansible-galaxy collection install -r aap_config/requirements.yml
```

### 2. Create vault file

```bash
cp aap_config/vault-example.yml aap_config/vault.yml
# Edit vault.yml with real values, then:
ansible-vault encrypt aap_config/vault.yml
```

### 3. (Once) Build and push the Decision Environment image

```bash
ansible-playbook decision-environment/build_de.yml
```
`build_de.yml` builds the DE with `podman`, pushes it to the OpenShift
internal imagestream `aap/eda-community-de:latest`, and registers it in AAP EDA.
Once pushed, subsequent `configure_aap.yml` runs just reference the image URL
without rebuilding.

### 4. Run full configuration

```bash
ansible-playbook aap_config/configure_aap.yml \
  -e @aap_config/vault.yml --ask-vault-pass
```

The dispatch role applies objects in dependency order:
`Organizations → Credentials → Projects → Inventories → Job Templates → EDA DE → EDA Credentials → EDA Projects → EDA Activations`

### 5. Run only a subset (tags)

```bash
# Only EDA objects
ansible-playbook aap_config/configure_aap.yml \
  -e @aap_config/vault.yml --ask-vault-pass --tags eda

# Only job templates
ansible-playbook aap_config/configure_aap.yml \
  -e @aap_config/vault.yml --ask-vault-pass --tags job_templates

# Only OCP Routes
ansible-playbook aap_config/configure_aap.yml \
  -e @aap_config/vault.yml --ask-vault-pass --tags routes
```

## Variable reference

### `infra.aap_configuration` dispatch variables used

| Variable | Role (Controller) |
|----------|-------------------|
| `aap_organizations` | `gateway_organizations` |
| `controller_credentials` | `controller_credentials` |
| `controller_inventories` | `controller_inventories` |
| `controller_hosts` | `controller_hosts` |
| `controller_inventory_sources` | `controller_inventory_sources` |
| `controller_projects` | `controller_projects` |
| `controller_templates` | `controller_job_templates` |

| Variable | Role (EDA) |
|----------|------------|
| `eda_decision_environments` | `eda_decision_environments` |
| `eda_credentials` | `eda_credentials` |
| `eda_projects` | `eda_projects` |
| `eda_rulebook_activations` | `eda_rulebook_activations` |

### Connection variables (from `vars/auth.yml` + vault)

| Variable | Description |
|----------|-------------|
| `aap_hostname` | Gateway URL (`https://aap-aap.apps-crc.testing`) |
| `aap_username` | Admin username |
| `aap_password` | Admin password (from vault) |
| `aap_validate_certs` | TLS verification (`false` for CRC) |
| `aws_access_key_id` | AWS key ID (from vault) |
| `aws_secret_access_key` | AWS secret key (from vault) |

## Idempotency

The playbook is fully idempotent — running it multiple times produces no
unintended changes.  The dispatch role uses `state: present` for all objects,
so existing objects are updated only if their definition changed.

## Converting from manual setup

If you previously used the individual `setup_aap.yml` playbooks per sample, the objects
they create are identical to those declared here.  Running `configure_aap.yml` will
bring any missing objects into existence and leave existing ones unchanged.
