#!/usr/bin/env bash
# Test 19 — Sequential execution strategy: first event (10s job)
#
# What this curl does:
#   POSTs the first deploy event to eda-execution-sequential-activation.
#   The activation uses execution_strategy=sequential, so a second event sent
#   while this job runs will queue until this one finishes (~10 seconds).
#
# Run with test 20 to observe queuing:
#   bash testcases/19_exec_sequential_event1.sh & sleep 1; bash testcases/20_exec_sequential_event2.sh
#
# Resources to verify it worked:
#   • OpenShift route: eda-execution-sequential-activation.apps-crc.testing (HTTP 200)
#   • AAP → Jobs: EDA-Execution-Strategy-Action, event_id=EVT-SEQ-001, ~10s duration
#   • AAP → EDA → Activations: eda-execution-sequential-activation strategy=sequential
curl -kv -X POST https://eda-execution-sequential-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"deploy","event_id":"EVT-SEQ-001","sleep_seconds":10,"requestor":"ops-team"}'
