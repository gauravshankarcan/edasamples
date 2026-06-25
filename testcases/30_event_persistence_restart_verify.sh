#!/usr/bin/env bash
# Test 30 — Event persistence: restart activation mid-flight and verify job completes
#
# Demonstrates AAP 2.7 enable_persistence:
#   1. Send a 30s event
#   2. Restart the activation while the job is running
#   3. Poll Controller until EDA-Event-Persistence-Action succeeds for EVT-PERSIST-001
#
# Prerequisites:
#   source ~/.bashrc_eda_session
#   ansible-playbook eda_event_persistence/setup_aap.yml
set -euo pipefail

: "${AAP_BASE:=https://aap-aap.apps-crc.testing}"
: "${AAP_USER:=admin}"
: "${AAP_PASS:?Set AAP_PASS (source ~/.bashrc_eda_session)}"

ACTIVATION_NAME="eda-event-persistence-activation"
EVENT_ID="EVT-PERSIST-001"
WEBHOOK_URL="https://${ACTIVATION_NAME}.apps-crc.testing"
EDA_API="${AAP_BASE}/api/eda/v1"
CTRL_API="${AAP_BASE}/api/controller/v2"
AUTH=(-u "${AAP_USER}:${AAP_PASS}")

echo "==> Step 1: Send long-running event (${EVENT_ID}, 30s sleep)"
curl -sk -X POST "${WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d "{\"event_type\":\"persist-test\",\"event_id\":\"${EVENT_ID}\",\"sleep_seconds\":30,\"persistence_enabled\":\"true\"}" \
  && echo

echo "==> Step 2: Wait 3s (job running, event in-flight)"
sleep 3

echo "==> Step 3: Look up activation ID"
ACTIVATION_ID=$(curl -sk "${AUTH[@]}" \
  "${EDA_API}/activations/?name=${ACTIVATION_NAME}" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['results'][0]['id'])")
echo "    Activation ID: ${ACTIVATION_ID}"

echo "==> Step 4: Restart activation (simulate crash / project auto-restart)"
curl -sk -X POST "${AUTH[@]}" \
  "${EDA_API}/activations/${ACTIVATION_ID}/restart/" \
  -H "Content-Type: application/json" \
  -d '{}' && echo

echo "==> Step 5: Wait for activation to return to running"
for _ in $(seq 1 30); do
  STATUS=$(curl -sk "${AUTH[@]}" \
    "${EDA_API}/activations/${ACTIVATION_ID}/" \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('status',''))")
  echo "    status=${STATUS}"
  [[ "${STATUS}" == "running" ]] && break
  sleep 5
done

echo "==> Step 6: Poll Controller for successful job (up to 90s)"
DEADLINE=$((SECONDS + 90))
FOUND=0
while (( SECONDS < DEADLINE )); do
  JOBS=$(curl -sk "${AUTH[@]}" \
    "${CTRL_API}/jobs/?job_template__name=EDA-Event-Persistence-Action&order_by=-finished&page_size=10")
  MATCH=$(echo "${JOBS}" | python3 -c "
import json, sys
event_id = '${EVENT_ID}'
data = json.load(sys.stdin)
for job in data.get('results', []):
    ev = job.get('extra_vars', '') or ''
    if event_id in ev and job.get('status') == 'successful':
        print(job['id'])
        break
")
  if [[ -n "${MATCH}" ]]; then
    echo "    SUCCESS: Job ${MATCH} completed for ${EVENT_ID}"
    FOUND=1
    break
  fi
  echo "    waiting... (${SECONDS}s elapsed)"
  sleep 5
done

if [[ "${FOUND}" -ne 1 ]]; then
  echo "FAILED: No successful EDA-Event-Persistence-Action job found for ${EVENT_ID}" >&2
  echo "Check AAP → Jobs and EDA activation logs (enable_persistence should be true)." >&2
  exit 1
fi

echo "==> Event persistence test passed"
