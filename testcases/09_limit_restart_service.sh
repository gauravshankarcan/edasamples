#!/usr/bin/env bash
curl -X POST https://eda-limit-jobs-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"restart_service","target_hosts":"eda-test-web01,eda-test-web02","service_name":"nginx","requestor":"ops-team"}'
