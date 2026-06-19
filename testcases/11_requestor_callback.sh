#!/usr/bin/env bash
curl -X POST https://eda-requestor-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"request_id":"REQ-001","action":"provision","callback_url":"https://webhook.site/your-unique-id","requestor":"portal","parameters":{"env":"dev","size":"small"}}'
