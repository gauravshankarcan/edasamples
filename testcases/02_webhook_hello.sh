#!/usr/bin/env bash
curl -X POST https://sample-webhook-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"hello","target":"world","version":"2.0.0"}'
