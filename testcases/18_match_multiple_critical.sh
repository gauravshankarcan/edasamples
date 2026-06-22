#!/usr/bin/env bash
# Test 18 — Multi-match rulebook: critical severity → TWO jobs
#
# What this curl does:
#   POSTs a critical alert to eda-match-multiple-activation. With
#   match_multiple_rules=true, both Handle-Critical-Remediation and
#   Handle-Critical-Notification rules fire, launching Action-A and Action-B.
#
# Resources to verify it worked:
#   • OpenShift route: eda-match-multiple-activation.apps-crc.testing (HTTP 200)
#   • AAP → Jobs: TWO jobs for the same event — EDA-Match-Multiple-Action-A
#     AND EDA-Match-Multiple-Action-B (both successful)
#   • AAP → EDA → Activations: eda-match-multiple-activation (match_multiple_rules on)
curl -kv -X POST https://eda-match-multiple-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"alert","severity":"critical","event_id":"EVT-MULTI-001","message":"disk 95% full","notification_channel":"slack"}'
