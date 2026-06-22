#!/usr/bin/env bash
# Test 05 — Parameterized scale action
#
# What this curl does:
#   POSTs a scale event with replicas=5 to eda-param-samples-activation. The
#   rulebook matches action=scale (requires replicas field) and passes
#   param_replicas to EDA-Param-Deploy-Service.
#
# Resources to verify it worked:
#   • OpenShift route: eda-param-samples-activation.apps-crc.testing (HTTP 200)
#   • AAP → Jobs: EDA-Param-Deploy-Service with param_action=scale, replicas=5
#   • Job stdout: "SCALING payment-api to 5 replicas" in production
curl -k -X POST https://eda-param-samples-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"scale","service":"payment-api","replicas":5,"environment":"production","requestor":"autoscaler"}'
