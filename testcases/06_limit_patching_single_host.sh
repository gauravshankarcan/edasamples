#!/usr/bin/env bash
# Test 06 — AWS host limit: patch single EC2 instance by name
#
# What this curl does:
#   POSTs a patching event to eda-limit-jobs-activation. The rulebook
#   (rulebooks/eda-limit-jobs.yml) launches EDA-Limit-OS-Patching with
#   --limit eda-test-web01 against the EDA-AWS-Dynamic-Inventory.
#
# Prerequisites:
#   • AWS test EC2 instances exist (eda_param_limit_jobs/aws/create_test_instances.yml)
#   • EDA-AWS-Dynamic-Inventory synced with ansible_host set to public IP
#   • EDA-EC2-SSH-Credential attached to the job template (ec2-user + eda-test-key)
#
# Resources to verify it worked:
#   • OpenShift route: eda-limit-jobs-activation.apps-crc.testing (HTTP 200)
#   • AAP → Inventories → EDA-AWS-Dynamic-Inventory: host eda-test-web01 present
#   • AAP → Jobs: EDA-Limit-OS-Patching, limit=eda-test-web01, status successful
#   • Job stdout: patching task runs on eda-test-web01 with OS facts gathered
curl -k -X POST https://eda-limit-jobs-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"patching","target_hosts":"eda-test-web01","requestor":"ops-team","change_id":"CHG001"}'
