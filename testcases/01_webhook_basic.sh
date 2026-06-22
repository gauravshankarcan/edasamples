#!/usr/bin/env bash
# Test 01 — Basic webhook → job template
#
# What this curl does:
#   POSTs a JSON event to the sample-webhook-activation OpenShift route. The EDA
#   rulebook (rulebooks/samples-webhook.yml) accepts any payload and launches the
#   EDA-Sample-Webhook-Handler job template with action/target/version extra vars.
#
# Resources to verify it worked:
#   • OpenShift route: sample-webhook-activation.apps-crc.testing (HTTP 200 = accepted)
#   • AAP → Automation Controller → Jobs: new EDA-Sample-Webhook-Handler job (successful)
#   • Job stdout: shows eda_event_action=deploy, eda_event_target=webserver, version=1.0.0
#   • AAP → EDA → Rulebook Activations: sample-webhook-activation status = running
curl -k -X POST https://sample-webhook-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"deploy","target":"webserver","version":"1.0.0"}'
