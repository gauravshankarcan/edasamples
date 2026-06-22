#!/usr/bin/env bash
# Test 17 — Single-match rulebook: high severity → ONE job (different rule)
#
# What this curl does:
#   POSTs a high-severity alert to eda-match-single-activation. Only the
#   Handle-High-Severity rule matches and launches EDA-Match-Multiple-Action-A.
#
# Resources to verify it worked:
#   • OpenShift route: eda-match-single-activation.apps-crc.testing (HTTP 200)
#   • AAP → Jobs: ONE EDA-Match-Multiple-Action-A job
#   • Job extra vars: eda_triggered_rule=Handle-High-Severity, severity=high
curl -kv -X POST https://eda-match-single-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"alert","severity":"high","event_id":"EVT-SINGLE-002","message":"cpu 90% sustained"}'
