#!/usr/bin/env bash
# Test 25 — Ansible Vault demo: rotate action
#
# What this curl does:
#   POSTs action=rotate to eda-vault-demo-activation. The EDA-Vault-Demo
#   playbook simulates a secret rotation workflow (dry-run — does not change
#   the encrypted vault file in the repo).
#
# Prerequisites: same as test 23 (vault credential + encrypted vault.yml)
#
# Resources to verify it worked:
#   • OpenShift route: eda-vault-demo-activation.apps-crc.testing (HTTP 200)
#   • AAP → Jobs: EDA-Vault-Demo, eda_event_action=rotate, status successful
#   • Job stdout: rotation simulation steps and "rotation complete (simulated)"
curl -kv -X POST https://eda-vault-demo-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"rotate","event_id":"EVT-VAULT-003","requestor":"automation"}'
