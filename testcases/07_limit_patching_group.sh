#!/usr/bin/env bash
# Test 07 — AWS host limit: patch all hosts in inventory group
#
# What this curl does:
#   POSTs a patching event with target_hosts=webservers. The AWS EC2 dynamic
#   inventory creates a "webservers" group from the Group tag on test instances.
#   EDA launches EDA-Limit-OS-Patching limited to that group (web01 + web02).
#
# Prerequisites: same as test 06 (AWS EC2 test infra + SSH credential + inventory sync)
#
# Resources to verify it worked:
#   • OpenShift route: eda-limit-jobs-activation.apps-crc.testing (HTTP 200)
#   • AAP → Inventories → EDA-AWS-Dynamic-Inventory → Groups: webservers (2 hosts)
#   • AAP → Jobs: EDA-Limit-OS-Patching, limit=webservers, 2 hosts in job events
curl -kv -X POST https://eda-limit-jobs-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"patching","target_hosts":"webservers","requestor":"ops-team","change_id":"CHG002"}'
