#!/usr/bin/env bash
# Test 15 — Azure host limit: target VMs by tag group (Group=webservers)
#
# What this curl does:
#   POSTs a patching event with azure_tag_key=Group and azure_tag_value=webservers
#   to eda-azure-limit-jobs-activation. The rulebook limits the job to the
#   webservers inventory group (VMs tagged Group=webservers).
#
# Prerequisites: same as test 14 (Azure test VMs + inventory sync)
#
# Resources to verify it worked:
#   • OpenShift route: eda-azure-limit-jobs-activation.apps-crc.testing (HTTP 200)
#   • AAP → Inventories → EDA-Azure-Inventory → Groups: webservers (2 VMs)
#   • AAP → Jobs: EDA-Azure-Limit-OS-Patching, limit=webservers, 2 hosts targeted
curl -k -X POST https://eda-azure-limit-jobs-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"patching","azure_tag_key":"Group","azure_tag_value":"webservers","requestor":"cloud-ops","change_id":"CHG-AZ-002"}'
