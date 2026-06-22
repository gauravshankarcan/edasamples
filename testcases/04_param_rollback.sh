#!/usr/bin/env bash
# Test 04 — Parameterized rollback action
#
# What this curl does:
#   POSTs a rollback event to eda-param-samples-activation. The rulebook matches
#   action=rollback and launches EDA-Param-Deploy-Service with rollback extra vars.
#
# Resources to verify it worked:
#   • OpenShift route: eda-param-samples-activation.apps-crc.testing (HTTP 200)
#   • AAP → Jobs: EDA-Param-Deploy-Service with param_action=rollback
#   • Job stdout: "ROLLING BACK payment-api to version 3.0.9" in staging
curl -kv -X POST https://eda-param-samples-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"rollback","service":"payment-api","version":"3.0.9","environment":"staging","requestor":"ops-team"}'
