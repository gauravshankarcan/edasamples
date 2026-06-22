#!/usr/bin/env bash
# Test 14 — Azure host limit: patch single VM by name
#
# What this curl does:
#   POSTs a patching event to eda-azure-limit-jobs-activation. The Azure
#   rulebook (rulebooks/eda-limit-jobs-azure.yml) launches
#   EDA-Azure-Limit-OS-Patching with --limit eda-test-web01 on EDA-Azure-Inventory.
#
# Prerequisites:
#   • Azure test VMs exist (eda_param_limit_jobs/azure/create_test_vms.yml)
#   • EDA-Azure-Inventory synced (VMs tagged Owner=eda-samples)
#   • EDA-Azure-Credential configured on job template
#
# Resources to verify it worked:
#   • OpenShift route: eda-azure-limit-jobs-activation.apps-crc.testing (HTTP 200)
#   • AAP → Inventories → EDA-Azure-Inventory: host eda-test-web01 present
#   • AAP → Jobs: EDA-Azure-Limit-OS-Patching, limit=eda-test-web01, successful
curl -kv -X POST https://eda-azure-limit-jobs-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"patching","target_hosts":"eda-test-web01","requestor":"ops-team","change_id":"CHG-AZ-001"}'
