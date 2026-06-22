#!/usr/bin/env bash
# Test 11 — Requestor callback pattern (outbound POST to Pipedream)
#
# What this curl does:
#   POSTs a provision request with callback_url to eda-requestor-activation.
#   The rulebook (rulebooks/eda-requestor.yml) launches EDA-Requestor-Handler,
#   which simulates provisioning then POSTs the JSON result back to callback_url.
#
# Outbound request:
#   The playbook POSTs to https://eok4z67q40cbzt2.m.pipedream.net with headers
#   X-EDA-Request-ID and X-EDA-Callback. Check Pipedream event history for the
#   callback payload (request_id, status, result, message).
#
# Resources to verify it worked:
#   • OpenShift route: eda-requestor-activation.apps-crc.testing (HTTP 200)
#   • AAP → Jobs: EDA-Requestor-Handler, status successful
#   • Job stdout: "Callback response code: 200" (or 201/202/204)
#   • Pipedream: https://eok4z67q40cbzt2.m.pipedream.net — incoming POST with
#     request_id=REQ-001, action=provision, status=success
curl -k -X POST https://eda-requestor-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"request_id":"REQ-001","action":"provision","callback_url":"https://eok4z67q40cbzt2.m.pipedream.net","requestor":"portal","parameters":{"env":"dev","size":"small"}}'
