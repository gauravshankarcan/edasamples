#!/usr/bin/env bash
curl -X POST https://eda-azure-limit-jobs-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"patching","target_hosts":"eda-test-web01","requestor":"ops-team","change_id":"CHG-AZ-001"}'
