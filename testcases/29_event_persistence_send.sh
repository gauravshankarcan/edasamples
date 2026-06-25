#!/usr/bin/env bash
# Test 29 — Event persistence: send long-running event (30s job)
#
# What this curl does:
#   POSTs a persist-test event to eda-event-persistence-activation.
#   The activation has enable_persistence=true so in-flight events survive restarts.
#
# Run with test 30 to restart mid-flight and verify the job still completes:
#   bash testcases/29_event_persistence_send.sh & sleep 3; bash testcases/30_event_persistence_restart_verify.sh
#
# Resources to verify:
#   • Route: eda-event-persistence-activation.apps-crc.testing
#   • AAP → EDA → Activations: enable_persistence=true
#   • AAP → Jobs: EDA-Event-Persistence-Action, event_id=EVT-PERSIST-001
set -euo pipefail

: "${AAP_BASE:=https://aap-aap.apps-crc.testing}"

curl -kv -X POST https://eda-event-persistence-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"persist-test","event_id":"EVT-PERSIST-001","sleep_seconds":30,"persistence_enabled":"true","requestor":"persistence-demo"}'
