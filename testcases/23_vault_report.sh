#!/usr/bin/env bash
curl -k -X POST https://eda-vault-demo-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"report","event_id":"EVT-VAULT-001","requestor":"ops-team"}'
