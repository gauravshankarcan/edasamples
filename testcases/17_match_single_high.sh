#!/usr/bin/env bash
curl -k -X POST https://eda-match-single-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"alert","severity":"high","event_id":"EVT-SINGLE-002","message":"cpu 90% sustained"}'
