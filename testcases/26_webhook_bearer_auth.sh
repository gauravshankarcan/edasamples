#!/usr/bin/env bash
# Test 26 — Bearer-token authenticated webhook
#
# What this curl does:
#   POSTs a JSON event to eda-webhook-bearer-activation with a valid
#   Authorization: Bearer header. The rulebook (rulebooks/eda-webhook-bearer.yml)
#   rejects unauthenticated requests and launches EDA-Sample-Webhook-Handler
#   with eda_auth_mode=bearer.
#
# Resources to verify it worked:
#   • OpenShift route: eda-webhook-bearer-activation.apps-crc.testing (HTTP 200)
#   • AAP → Automation Controller → Jobs: new EDA-Sample-Webhook-Handler job
#   • Job stdout: eda_auth_mode=bearer, eda_event_target=secure-host
#   • AAP → EDA → Activations: eda-webhook-bearer-activation status = running
curl -kv -X POST https://eda-webhook-bearer-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eda-bearer-demo-token" \
  -d '{"action":"deploy","target":"secure-host","version":"1.0.0"}'
