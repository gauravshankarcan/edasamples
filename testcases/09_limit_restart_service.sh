#!/usr/bin/env bash
# Test 09 — AWS host limit: restart nginx on multiple named hosts
#
# What this curl does:
#   POSTs a restart_service event with a comma-separated target_hosts list and
#   service_name=nginx. EDA limits the job to eda-test-web01,eda-test-web02.
#
# Prerequisites: same as test 06 (AWS EC2 test infra + SSH credential + inventory sync)
#
# Resources to verify it worked:
#   • OpenShift route: eda-limit-jobs-activation.apps-crc.testing (HTTP 200)
#   • AAP → Jobs: EDA-Limit-OS-Patching, limit=eda-test-web01,eda-test-web02
#   • Job stdout: "RESTART nginx" debug message on both web hosts
curl -k -X POST https://eda-limit-jobs-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"restart_service","target_hosts":"eda-test-web01,eda-test-web02","service_name":"nginx","requestor":"ops-team"}'
