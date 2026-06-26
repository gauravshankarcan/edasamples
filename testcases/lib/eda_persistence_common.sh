#!/usr/bin/env bash
# Shared helpers for event persistence testcases (29, 30).

eda_persist_auth() {
  : "${AAP_USER:=admin}"
  : "${AAP_PASS:?Set AAP_PASS (source ~/.bashrc_eda_session)}"
  export AAP_USER AAP_PASS
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

eda_persist_wait_listening() {
  local activation_name="${1:?activation name}"
  local deadline=$((SECONDS + ${2:-120}))

  while (( SECONDS < deadline )); do
    local act_id inst_id ready
    act_id=$(curl -sk "${AUTH[@]}" "${EDA_API}/activations/?name=${activation_name}" \
      | python3 -c "import json,sys; r=json.load(sys.stdin).get('results',[]); print(r[0]['id'] if r else '')")
    if [[ -z "${act_id}" ]]; then
      sleep 3
      continue
    fi
    inst_id=$(curl -sk "${AUTH[@]}" \
      "${EDA_API}/activation-instances/?activation_id=${act_id}&order_by=-id&page_size=1" \
      | python3 -c "import json,sys; r=json.load(sys.stdin).get('results',[]); print(r[0]['id'] if r else '')")
    if [[ -z "${inst_id}" ]]; then
      sleep 3
      continue
    fi
    ready=$(curl -sk "${AUTH[@]}" "${EDA_API}/activation-instances/${inst_id}/logs/?page_size=20" \
      | python3 -c "
import json, sys, urllib.request, base64, os
inst_id = '${inst_id}'
api = '${EDA_API}/activation-instances/' + inst_id + '/logs/'
auth = base64.b64encode(f\"{os.environ.get('AAP_USER','admin')}:{os.environ['AAP_PASS']}\".encode()).decode()
def fetch(url):
    req = urllib.request.Request(url, headers={'Authorization': f'Basic {auth}'})
    ctx = urllib.request.ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = 0
    with urllib.request.urlopen(req, context=ctx) as resp:
        return json.load(resp)
data = fetch(api + '?page_size=20')
count = data.get('count', 0)
page_size = data.get('page_size', 20) or 20
last_page = max(1, (count + page_size - 1) // page_size)
data = fetch(f'{api}?page={last_page}&page_size={page_size}')
text = '\n'.join(r.get('log', '') for r in data.get('results', []))
markers = (
    'Waiting for events',
    'Waiting for actions on events',
    'Recovered session',
)
print('ready' if any(m in text for m in markers) else '')
")
    if [[ "${ready}" == "ready" ]]; then
      return 0
    fi
    echo "    waiting for webhook listener (instance=${inst_id})..." >&2
    sleep 3
  done

  echo "FAILED: Activation ${activation_name} webhook not listening after ${2:-120}s" >&2
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
    echo "    waiting for job (batch=${batch_id})... (${SECONDS}s elapsed)" >&2
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
