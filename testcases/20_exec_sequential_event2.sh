#!/usr/bin/env bash
curl -X POST https://eda-execution-sequential-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"deploy","event_id":"EVT-SEQ-002","sleep_seconds":5,"requestor":"ops-team"}'
