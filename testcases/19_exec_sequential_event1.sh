#!/usr/bin/env bash
curl -k -X POST https://eda-execution-sequential-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"deploy","event_id":"EVT-SEQ-001","sleep_seconds":10,"requestor":"ops-team"}'
