#!/usr/bin/env bash
curl -k -X POST https://eda-param-samples-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"rollback","service":"payment-api","version":"3.0.9","environment":"staging","requestor":"ops-team"}'
