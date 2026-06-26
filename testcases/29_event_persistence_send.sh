#!/usr/bin/env bash
# Test 29 — Event persistence: single hit does NOT trigger job (counter = 1 of 3)
#
# State preservation demo (Drools facts):
#   • Rule fires a Controller job only after 3 threshold-hit events within 10 minutes
#   • One hit increments facts.threshold_count but must not launch a job yet
#
# Verifies:
#   1. Activation status = running
#   2. threshold-reset + 1× threshold-hit → HTTP 200
#   3. No new EDA-Event-Persistence-Action job for this batch (count < 3)
#
# Full persistence proof: testcases/30_event_persistence_restart_verify.sh
set -euo pipefail

: "${AAP_BASE:=https://aap-aap.apps-crc.testing}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/eda_persistence_common.sh
source "${SCRIPT_DIR}/lib/eda_persistence_common.sh"

ACTIVATION_NAME="eda-event-persistence-activation"
WEBHOOK_URL="https://${ACTIVATION_NAME}.apps-crc.testing"
EDA_API="${AAP_BASE}/api/eda/v1"
CTRL_API="${AAP_BASE}/api/controller/v2"
BATCH_ID="PERSIST-SMOKE-$(date +%s)"
SENT_AT=$(date -u +%Y-%m-%dT%H:%M:%S)

eda_persist_auth

echo "==> Step 1: Wait for activation running (batch=${BATCH_ID})"
eda_persist_wait_running "${ACTIVATION_NAME}" 120

echo "==> Step 2: Reset Drools counter and send 1 of 3 threshold hits"
eda_persist_send_reset "${WEBHOOK_URL}" "${BATCH_ID}"
HTTP_CODE=$(eda_persist_send_hit "${WEBHOOK_URL}" "${BATCH_ID}" 1)
echo "    HTTP ${HTTP_CODE}"
if [[ "${HTTP_CODE}" != "200" ]]; then
  echo "FAILED: Webhook returned HTTP ${HTTP_CODE} (expected 200)" >&2
  head -5 /tmp/eda-persist-webhook-body.txt >&2 || true
  exit 1
fi

echo "==> Step 3: Confirm no threshold job yet (expect count=1 of 3, no Controller job)"
if ! eda_persist_poll_job "${BATCH_ID}" "${SENT_AT}" 0 12; then
  exit 1
fi

echo "==> Event persistence smoke test passed (1 hit accepted, no job — counter not at threshold)"
