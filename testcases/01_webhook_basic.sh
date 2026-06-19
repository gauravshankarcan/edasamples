#!/usr/bin/env bash
curl -k -X POST https://sample-webhook-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"deploy","target":"webserver","version":"1.0.0"}'
