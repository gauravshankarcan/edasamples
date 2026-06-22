#!/usr/bin/env bash
# Test 16 — Single-match rulebook: critical severity → ONE job
#
# What this curl does:
#   POSTs a critical alert to eda-match-single-activation. With default
#   match_multiple_rules=false, only the first matching rule fires
#   (Handle-Critical-Severity) and launches EDA-Match-Multiple-Action-A once.
#
# Resources to verify it worked:
#   • OpenShift route: eda-match-single-activation.apps-crc.testing (HTTP 200)
#   • AAP → Jobs: exactly ONE EDA-Match-Multiple-Action-A job (not two)
#   • Job extra vars: eda_triggered_rule=Handle-Critical-Severity, severity=critical
#   • AAP → EDA → Activations: eda-match-single-activation (match_multiple_rules off)
curl -kv -X POST https://eda-match-single-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"alert","severity":"critical","event_id":"EVT-SINGLE-001","message":"disk 95% full"}'
