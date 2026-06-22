#!/usr/bin/env bash
# Test 21 — Parallel execution strategy: first event (10s job)
#
# What this curl does:
#   POSTs the first alert event to eda-execution-parallel-activation.
#   The activation uses execution_strategy=parallel, so a second event sent
#   immediately will start its own job concurrently (no queuing).
#
# Run with test 22 to observe concurrency:
#   bash testcases/21_exec_parallel_event1.sh & sleep 1; bash testcases/22_exec_parallel_event2.sh
#
# Resources to verify it worked:
#   • OpenShift route: eda-execution-parallel-activation.apps-crc.testing (HTTP 200)
#   • AAP → Jobs: EDA-Execution-Strategy-Action, event_id=EVT-PAR-001, ~10s duration
#   • AAP → EDA → Activations: eda-execution-parallel-activation strategy=parallel
curl -kv -X POST https://eda-execution-parallel-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"alert","event_id":"EVT-PAR-001","sleep_seconds":10,"requestor":"monitoring"}'
