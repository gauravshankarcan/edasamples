#!/usr/bin/env bash
# Shared helpers for event persistence testcases (29, 30).

eda_persist_auth() {
  : "${AAP_USER:=admin}"
  : "${AAP_PASS:?Set AAP_PASS (source ~/.bashrc_eda_session)}"
  AUTH=(-u "${AAP_USER}:${AAP_PASS}")
}

eda_persist_wait_running() {
  local activation_name="${1:?activation name}"
  local deadline=$((SECONDS + ${2:-120}))
  local status=""

  while (( SECONDS < deadline )); do
    local act_json
    act_json=$(curl -sk "${AUTH[@]}" "${EDA_API}/activations/?name=${activation_name}")
    local count
    count=$(echo "${act_json}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('count',0))")
    if [[ "${count}" -lt 1 ]]; then
      echo "    activation not found"
      sleep 5
      continue
    fi
    status=$(echo "${act_json}" | python3 -c "import json,sys; print(json.load(sys.stdin)['results'][0]['status'])")
    local msg
    msg=$(echo "${act_json}" | python3 -c "import json,sys; print(json.load(sys.stdin)['results'][0].get('status_message',''))")
    echo "    status=${status} (${msg})"
    if [[ "${status}" == "running" ]]; then
      return 0
    fi
    if [[ "${status}" == "failed" || "${status}" == "error" ]]; then
      echo "FAILED: Activation ${activation_name} is ${status}: ${msg}" >&2
      return 1
    fi
    sleep 5
  done

  echo "FAILED: Activation ${activation_name} not running after ${2:-120}s (status=${status})" >&2
  return 1
}

eda_persist_ts() {
  date +%s
}

eda_persist_post_event() {
  local webhook_url="${1:?url}"
  local payload="${2:?json payload}"
  local http_code
  http_code=$(curl -sk -o /tmp/eda-persist-webhook-body.txt -w "%{http_code}" \
    -X POST "${webhook_url}" \
    -H "Content-Type: application/json" \
    -d "${payload}")
  echo "${http_code}"
}

eda_persist_send_reset() {
  local webhook_url="${1:?url}"
  local batch_id="${2:?batch}"
  eda_persist_post_event "${webhook_url}" \
    "{\"event_type\":\"threshold-reset\",\"batch_id\":\"${batch_id}\"}" >/dev/null
}

eda_persist_send_hit() {
  local webhook_url="${1:?url}"
  local batch_id="${2:?batch}"
  local seq="${3:?1-3}"
  local ts
  ts=$(eda_persist_ts)
  local http_code
  http_code=$(eda_persist_post_event "${webhook_url}" \
    "{\"event_type\":\"threshold-hit\",\"batch_id\":\"${batch_id}\",\"hit_seq\":${seq},\"ts\":${ts}}")
  echo "${http_code}"
}

eda_persist_poll_job() {
  local batch_id="${1:?batch}"
  local sent_at="${2:?iso timestamp}"
  local expect_job="${3:-1}"
  local deadline=$((SECONDS + ${4:-90}))

  while (( SECONDS < deadline )); do
    local jobs match
    jobs=$(curl -sk "${AUTH[@]}" \
      "${CTRL_API}/jobs/?job_template__name=EDA-Event-Persistence-Action&order_by=-created&page_size=20")
    match=$(echo "${jobs}" | python3 -c "
import json, sys
batch_id = '${batch_id}'
sent_at = '${sent_at}'
data = json.load(sys.stdin)
for job in data.get('results', []):
    ev = job.get('extra_vars', '') or ''
    created = job.get('created', '') or ''
    if batch_id in ev and created >= sent_at:
        print(job['id'], job.get('status', ''))
        break
")
    if [[ -n "${match}" ]]; then
      if [[ "${expect_job}" == "1" ]]; then
        echo "${match}"
        return 0
      fi
      echo "FAILED: Unexpected job for batch ${batch_id}: ${match}" >&2
      return 1
    fi
    if [[ "${expect_job}" == "0" ]]; then
      sleep 5
      continue
    fi
    echo "    waiting for job (batch=${batch_id})... (${SECONDS}s elapsed)"
    sleep 5
  done

  if [[ "${expect_job}" == "1" ]]; then
    echo "FAILED: No EDA-Event-Persistence-Action job for batch ${batch_id}" >&2
    return 1
  fi
  return 0
}

eda_persist_activation_persistence_enabled() {
  local activation_name="${1:?name}"
  curl -sk "${AUTH[@]}" "${EDA_API}/activations/?name=${activation_name}" \
    | python3 -c "import json,sys; r=json.load(sys.stdin)['results']; print('true' if r and r[0].get('enable_persistence') else 'false')"
}
