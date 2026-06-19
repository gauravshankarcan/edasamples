#!/usr/bin/env bash
curl -X POST https://eda-match-multiple-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"alert","severity":"critical","event_id":"EVT-MULTI-001","message":"disk 95% full","notification_channel":"slack"}'
