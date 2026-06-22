#!/usr/bin/env bash
# Test 23 — Ansible Vault demo: report action
#
# What this curl does:
#   POSTs action=report to eda-vault-demo-activation. The rulebook
#   (rulebooks/eda-vault-demo.yml) launches EDA-Vault-Demo, which loads
#   ansible-vault encrypted secrets from eda_vault_demo/vars/vault.yml using
#   the EDA-Vault-Credential (Vault Password) attached to the job template.
#
# Prerequisites:
#   • EDA-Vault-Credential configured with vault password (~/.vault_pass_eda_demo)
#   • eda_vault_demo/vars/vault.yml encrypted and present in the project
#
# Resources to verify it worked:
#   • OpenShift route: eda-vault-demo-activation.apps-crc.testing (HTTP 200)
#   • AAP → Jobs: EDA-Vault-Demo, eda_event_action=report, status successful
#   • Job stdout: secret lengths/prefixes shown (values never printed in clear text)
#   • AAP → Credentials: EDA-Vault-Credential attached to EDA-Vault-Demo template
curl -kv -X POST https://eda-vault-demo-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"report","event_id":"EVT-VAULT-001","requestor":"ops-team"}'
