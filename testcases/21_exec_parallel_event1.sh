#!/usr/bin/env bash
curl -X POST https://eda-execution-parallel-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"alert","event_id":"EVT-PAR-001","sleep_seconds":10,"requestor":"monitoring"}'
