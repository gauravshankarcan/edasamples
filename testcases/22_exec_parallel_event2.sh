#!/usr/bin/env bash
# Test 22 — Parallel execution strategy: second event (runs concurrently)
#
# What this curl does:
#   POSTs a second alert event to eda-execution-parallel-activation while
#   test 21's job is still running. With parallel strategy, both jobs run
#   at the same time (overlapping start times).
#
# Run with test 21:
#   bash testcases/21_exec_parallel_event1.sh & sleep 1; bash testcases/22_exec_parallel_event2.sh
#
# Resources to verify it worked:
#   • OpenShift route: eda-execution-parallel-activation.apps-crc.testing (HTTP 200)
#   • AAP → Jobs: EVT-PAR-001 and EVT-PAR-002 have overlapping run windows
#   • Compare job timelines — second job starts within ~1s of the first
curl -k -X POST https://eda-execution-parallel-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"alert","event_id":"EVT-PAR-002","sleep_seconds":5,"requestor":"monitoring"}'
