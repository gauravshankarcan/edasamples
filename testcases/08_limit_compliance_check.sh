#!/usr/bin/env bash
# Test 08 — AWS host limit: compliance check by Environment tag group
#
# What this curl does:
#   POSTs a compliance_check event targeting all three AWS test instances by name.
#   The rulebook passes target_hosts as the job limit for EDA-Limit-OS-Patching.
#
# Prerequisites: same as test 06 (AWS EC2 test infra + SSH credential + inventory sync)
#
# Resources to verify it worked:
#   • OpenShift route: eda-limit-jobs-activation.apps-crc.testing (HTTP 200)
#   • AAP → Inventories → EDA-AWS-Dynamic-Inventory: 3 hosts (web01, web02, db01)
#   • AAP → Jobs: EDA-Limit-OS-Patching, limit lists 3 hosts, compliance_check tasks
#   • Job stdout: disk usage (df -h) output per host
curl -kv -X POST https://eda-limit-jobs-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"compliance_check","target_hosts":"eda-test-web01,eda-test-web02,eda-test-db01","requestor":"security-team","change_id":"SEC001"}'
