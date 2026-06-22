#!/usr/bin/env bash
# Test 24 — Ansible Vault demo: verify action
#
# What this curl does:
#   POSTs action=verify to eda-vault-demo-activation. The EDA-Vault-Demo
#   playbook decrypts vault_db_password and asserts it meets complexity rules
#   (length, uppercase, digit, special character).
#
# Prerequisites: same as test 23 (vault credential + encrypted vault.yml)
#
# Resources to verify it worked:
#   • OpenShift route: eda-vault-demo-activation.apps-crc.testing (HTTP 200)
#   • AAP → Jobs: EDA-Vault-Demo, eda_event_action=verify, status successful
#   • Job stdout: "vault_db_password complexity check PASSED"
curl -kv -X POST https://eda-vault-demo-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"verify","event_id":"EVT-VAULT-002","requestor":"security-team"}'
