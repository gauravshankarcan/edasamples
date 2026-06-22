#!/usr/bin/env bash
# Test 02 — Alternate webhook payload (same activation as test 01)
#
# What this curl does:
#   POSTs a different JSON payload to the same sample-webhook-activation route.
#   Demonstrates that any webhook JSON is forwarded to the job template as extra vars.
#
# Resources to verify it worked:
#   • OpenShift route: sample-webhook-activation.apps-crc.testing (HTTP 200)
#   • AAP → Jobs: EDA-Sample-Webhook-Handler with eda_event_action=hello, target=world
#   • Job stdout: audit record written under /tmp on the controller execution node
curl -kv -X POST https://sample-webhook-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"hello","target":"world","version":"2.0.0"}'
