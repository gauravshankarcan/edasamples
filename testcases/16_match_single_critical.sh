#!/usr/bin/env bash
curl -X POST https://eda-match-single-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"alert","severity":"critical","event_id":"EVT-SINGLE-001","message":"disk 95% full"}'
