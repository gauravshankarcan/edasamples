# EDA Vault Demo — Ansible Vaulted Variables with EDA

This sample demonstrates how to securely pass encrypted secrets into EDA-triggered playbooks using Ansible Vault. A webhook event fires an EDA rulebook, which calls a job template in AAP Controller. The Controller decrypts the vaulted variables at runtime using an attached Vault credential — no plaintext secrets are ever committed to SCM.

## Concepts Illustrated

| Concept | Where |
|---------|-------|
| `ansible-vault encrypt_string` inline vault string | `vars/vault.yml` |
| Vault credential in AAP Controller | `setup_aap.yml` → EDA-Vault-Credential |
| `vars_files:` loading an encrypted YAML | `playbooks/use_vaulted_secret.yml` |
| EDA → AAP → decrypted secret in playbook | `rulebooks/eda-vault-demo.yml` |
| Never logging secret values | `use_vaulted_secret.yml` tasks |

## Directory Layout

```
eda_vault_demo/
├── playbooks/
│   └── use_vaulted_secret.yml   # main playbook — asserts + uses vaulted vars
├── vars/
│   ├── vault.yml                # ansible-vault encrypted secrets (committed encrypted)
│   └── vault-example.yml        # unencrypted template showing the structure
├── setup_aap.yml                # standalone playbook to configure AAP for this demo
└── README.md
```

## Understanding Ansible Vault — Three Storage Patterns

### Pattern 1 — Inline vault strings in a vars file (this demo)

Individual variables are encrypted in-place with `ansible-vault encrypt_string`. The file itself is valid YAML; only the values are ciphertext. This is ideal for SCM-tracked secrets because diffs remain readable (only the encrypted blob changes).

```yaml
# vars/vault.yml — the !vault | tag marks an inline encrypted value
vault_db_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  63313236...
```

Create a new encrypted value:

```bash
ansible-vault encrypt_string 'MySuperSecret' --name vault_db_password \
  --vault-password-file ~/.vault_pass_eda_demo
```

### Pattern 2 — Whole-file encryption

Encrypt the entire file so its contents are opaque:

```bash
ansible-vault encrypt vars/vault.yml --vault-password-file ~/.vault_pass_eda_demo
ansible-vault view   vars/vault.yml --vault-password-file ~/.vault_pass_eda_demo
ansible-vault edit   vars/vault.yml --vault-password-file ~/.vault_pass_eda_demo
```

### Pattern 3 — AAP Controller Vault Credential (production)

Store the vault password in AAP (never on disk) as a **Vault Password** credential type. AAP injects it into the playbook execution environment automatically.

```
AAP → Resources → Credentials → New Credential
  Credential Type: Vault
  Vault Password: <your vault password>
```

Attach this credential to the job template; `vars_files:` in the playbook decrypts transparently at runtime.

## Vault Password for This Demo

| Item | Value |
|------|-------|
| AAP Credential name | `EDA-Vault-Credential` |
| Local test file | `~/.vault_pass_eda_demo` |
| Demo vault password | `EDA-Vault-Demo-Pass-2026!` *(change in production)* |

Create the local test file:

```bash
echo 'EDA-Vault-Demo-Pass-2026!' > ~/.vault_pass_eda_demo
chmod 600 ~/.vault_pass_eda_demo
```

## Setup

### Full stack (configure_aap.yml)

The vault demo is included in the main `configure_aap.yml` run:

```bash
cd aap_config
ansible-playbook configure_aap.yml \
  --vault-password-file ~/.vault_pass \
  -e vault_aap_password="${AAP_PASS}" \
  -e vault_vault_password="EDA-Vault-Demo-Pass-2026!" \
  --tags controller,eda
```

### Standalone

```bash
ansible-playbook eda_vault_demo/setup_aap.yml \
  -e vault_aap_password="${AAP_PASS}" \
  -e vault_password="EDA-Vault-Demo-Pass-2026!"
```

## Local Test (without AAP)

Verify the playbook + vault decryption locally:

```bash
ansible-playbook eda_vault_demo/playbooks/use_vaulted_secret.yml \
  --vault-password-file ~/.vault_pass_eda_demo \
  -e eda_event_action=report \
  -e eda_event_id=TEST-LOCAL-001 \
  -e eda_requestor=developer \
  -c local -i localhost,
```

Expected output shows `[REDACTED — length=...]` for each secret and `SUCCESS` for the assert task.

## Webhook Test Cases

| Script | Action | What it tests |
|--------|--------|---------------|
| `testcases/23_vault_report.sh` | `report` | Vault loads, secrets are defined |
| `testcases/24_vault_verify.sh` | `verify` | `vault_db_password` meets complexity rules |
| `testcases/25_vault_rotate.sh` | `rotate` | Simulated rotation workflow |

```bash
# Report — confirm secrets are accessible
bash testcases/23_vault_report.sh

# Verify — assert password complexity
bash testcases/24_vault_verify.sh

# Rotate — simulate rotation
bash testcases/25_vault_rotate.sh
```

## How the Secret Never Leaks

1. `vars/vault.yml` is committed to SCM but every secret value is a `!vault |` cipher block — plaintext is never in git history.
2. The playbook prints `[REDACTED — length=N]` instead of the actual value.
3. `no_log: true` is set on any task that handles the vault password itself.
4. AAP Controller stores the vault password as a Vault credential — it is write-only and never returned by the API.

## Adding a New Secret

```bash
# 1. Encrypt the new value
ansible-vault encrypt_string 'NewApiKey456' --name vault_new_api_key \
  --vault-password-file ~/.vault_pass_eda_demo

# 2. Paste the !vault | block into vars/vault.yml

# 3. Add the variable to the playbook's assert / tasks

# 4. Commit and push; AAP will sync and decrypt at runtime
git add eda_vault_demo/vars/vault.yml
git commit -m "Add vault_new_api_key to eda_vault_demo"
git push
```
