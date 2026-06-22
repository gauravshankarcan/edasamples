#!/usr/bin/env bash
# Test 20 — Sequential execution strategy: second event (waits for first)
#
# What this curl does:
#   POSTs a second deploy event to eda-execution-sequential-activation while
#   test 19's job is still running. With sequential strategy, this job should
#   NOT start until EVT-SEQ-001 completes.
#
# Run with test 19:
#   bash testcases/19_exec_sequential_event1.sh & sleep 1; bash testcases/20_exec_sequential_event2.sh
#
# Resources to verify it worked:
#   • OpenShift route: eda-execution-sequential-activation.apps-crc.testing (HTTP 200)
#   • AAP → Jobs: EVT-SEQ-002 start time is AFTER EVT-SEQ-001 finished time
#   • Compare job timelines — second job queued ~10s behind the first
curl -kv -X POST https://eda-execution-sequential-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"deploy","event_id":"EVT-SEQ-002","sleep_seconds":5,"requestor":"ops-team"}'
