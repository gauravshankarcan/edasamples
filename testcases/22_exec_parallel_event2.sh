#!/usr/bin/env bash
curl -X POST https://eda-execution-parallel-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"alert","event_id":"EVT-PAR-002","sleep_seconds":5,"requestor":"monitoring"}'
