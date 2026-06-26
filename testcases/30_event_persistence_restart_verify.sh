#!/usr/bin/env bash
# Test 30 — Event persistence: Drools state survives activation restart
#
# Scenario (3 events within 10 minutes, job on the 3rd):
#   1. Reset counter
#   2. Send threshold-hit #1 and #2  (facts.threshold_count → 2)
#   3. Restart activation            (counter lost unless enable_persistence)
#   4. Send threshold-hit #3         (count → 3 with persistence → job fires)
#
# With enable_persistence=true, facts survive restart and the job runs on hit #3.
# Without persistence, hit #3 only sees count=1 and no job is launched.
#
# Prerequisites:
#   source ~/.bashrc_eda_session
#   enable_persistence=true on eda-event-persistence-activation (EDA 2.7+ server)
set -euo pipefail

: "${AAP_BASE:=https://aap-aap.apps-crc.testing}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/eda_persistence_common.sh
source "${SCRIPT_DIR}/lib/eda_persistence_common.sh"

ACTIVATION_NAME="eda-event-persistence-activation"
WEBHOOK_URL="https://${ACTIVATION_NAME}.apps-crc.testing"
EDA_API="${AAP_BASE}/api/eda/v1"
CTRL_API="${AAP_BASE}/api/controller/v2"
BATCH_ID="PERSIST-RESTART-$(date +%s)"

eda_persist_auth

echo "==> Step 0: Check enable_persistence (required for this test)"
PERSIST=$(eda_persist_activation_persistence_enabled "${ACTIVATION_NAME}")
echo "    enable_persistence=${PERSIST}"
if [[ "${PERSIST}" != "true" ]]; then
  echo "SKIP: enable_persistence is false — restart will reset Drools facts." >&2
  echo "      Enable persistence in the UI (and EDA 2.7+ server) then re-run." >&2
  exit 2
fi

echo "==> Step 1: Wait for activation running (batch=${BATCH_ID})"
eda_persist_wait_running "${ACTIVATION_NAME}" 120

echo "==> Step 2: Reset counter and send hits 1 and 2"
eda_persist_send_reset "${WEBHOOK_URL}" "${BATCH_ID}"
for n in 1 2; do
  code=$(eda_persist_send_hit "${WEBHOOK_URL}" "${BATCH_ID}" "${n}")
  echo "    hit ${n}: HTTP ${code}"
  [[ "${code}" == "200" ]] || { echo "FAILED: hit ${n} returned ${code}" >&2; exit 1; }
  sleep 1
done
echo "    waiting for Drools facts to persist before restart..."
sleep 8

echo "==> Step 3: Restart activation (simulates crash / project reload)"
ACTIVATION_ID=$(curl -sk "${AUTH[@]}" \
  "${EDA_API}/activations/?name=${ACTIVATION_NAME}" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['results'][0]['id'])")
curl -sk -X POST "${AUTH[@]}" \
  "${EDA_API}/activations/${ACTIVATION_ID}/restart/" \
  -H "Content-Type: application/json" -d '{}' >/dev/null
echo "    restarted activation id=${ACTIVATION_ID}"

eda_persist_wait_running "${ACTIVATION_NAME}" 180
eda_persist_wait_listening "${ACTIVATION_NAME}" 120

echo "==> Step 4: Send hit 3 — should reach threshold if state was preserved"
SENT_AT=$(date -u +%Y-%m-%dT%H:%M:%S)
code=$(eda_persist_send_hit "${WEBHOOK_URL}" "${BATCH_ID}" 3)
echo "    hit 3: HTTP ${code}"
[[ "${code}" == "200" ]] || { echo "FAILED: hit 3 returned ${code}" >&2; exit 1; }

echo "==> Step 5: Poll for threshold job (batch=${BATCH_ID})"
JOB_MATCH=$(eda_persist_poll_job "${BATCH_ID}" "${SENT_AT}" 1 120) || exit 1
read -r JOB_ID JOB_STATUS <<< "${JOB_MATCH}"
echo "    SUCCESS: Job ${JOB_ID} status=${JOB_STATUS} — Drools count survived restart"

echo "==> Event persistence state-preservation test passed"
