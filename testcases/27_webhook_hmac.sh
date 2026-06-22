#!/usr/bin/env bash
# Test 27 — HMAC-verified webhook
#
# What this curl does:
#   POSTs a JSON event to eda-webhook-hmac-activation with an HMAC-SHA256
#   signature in x-hub-signature-256. The rulebook (rulebooks/eda-webhook-hmac.yml)
#   verifies the body against the shared secret and launches
#   EDA-Sample-Webhook-Handler with eda_auth_mode=hmac.
#
# Resources to verify it worked:
#   • OpenShift route: eda-webhook-hmac-activation.apps-crc.testing (HTTP 200)
#   • AAP → Automation Controller → Jobs: new EDA-Sample-Webhook-Handler job
#   • Job stdout: eda_auth_mode=hmac, eda_event_target=hmac-host
#   • AAP → EDA → Activations: eda-webhook-hmac-activation status = running
BODY='{"action":"deploy","target":"hmac-host","version":"1.0.0"}'
SIG=$(python3 - <<'PY'
import hmac
import hashlib
body = '{"action":"deploy","target":"hmac-host","version":"1.0.0"}'
print(hmac.new(b"eda-hmac-demo-secret", body.encode(), hashlib.sha256).hexdigest())
PY
)
curl -kv -X POST https://eda-webhook-hmac-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -H "x-hub-signature-256: sha256=${SIG}" \
  -d "$BODY"
