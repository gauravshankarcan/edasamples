#!/usr/bin/env bash
# Test 28 — mTLS-authenticated webhook
#
# What this curl does:
#   POSTs a JSON event to eda-webhook-mtls-activation over HTTPS with a client
#   certificate. The rulebook (rulebooks/eda-webhook-mtls.yml) terminates TLS
#   inside the activation pod, verifies the client cert against the demo CA, and
#   launches EDA-Sample-Webhook-Handler with eda_auth_mode=mtls.
#
# Resources to verify it worked:
#   • OpenShift route: eda-webhook-mtls-activation.apps-crc.testing (TLS passthrough)
#   • AAP → Automation Controller → Jobs: new EDA-Sample-Webhook-Handler job
#   • Job stdout: eda_auth_mode=mtls, eda_event_target=mtls-host
#   • AAP → EDA → Activations: eda-webhook-mtls-activation status = running
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="${SCRIPT_DIR}/../eda_webhook_security/certs"
curl -kv --cert "${CERT_DIR}/client.crt" \
  --key "${CERT_DIR}/client.key" \
  --cacert "${CERT_DIR}/ca.crt" \
  -X POST "https://eda-webhook-mtls-activation.apps-crc.testing/" \
  -H "Content-Type: application/json" \
  -d '{"action":"deploy","target":"mtls-host","version":"1.0.0"}'
