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

eda_persist_activation_id() {
  local activation_name="${1:?activation name}"
  curl -sk "${AUTH[@]}" "${EDA_API}/activations/?name=${activation_name}" \
    | python3 -c "import json,sys; r=json.load(sys.stdin).get('results',[]); print(r[0]['id'] if r else '')"
}

eda_persist_restart_activation() {
  local activation_name="${1:?activation name}"
  local act_id
  act_id=$(eda_persist_activation_id "${activation_name}")
  if [[ -z "${act_id}" ]]; then
    echo "FAILED: Activation ${activation_name} not found" >&2
    return 1
  fi
  curl -sk -X POST "${AUTH[@]}" \
    "${EDA_API}/activations/${act_id}/restart/" \
    -H "Content-Type: application/json" -d '{}' >/dev/null
}

eda_persist_clear_session_state() {
  local activation_id="${1:?activation id}"
  : "${KUBECONFIG:=${HOME}/.kube/config}"
  : "${OCP_CONTEXT:=crc-admin}"
  : "${EDA_PG_NAMESPACE:=aap}"
  : "${EDA_PG_POD:=aap-postgres-15-0}"

  if ! command -v oc >/dev/null 2>&1; then
    echo "    WARN: oc not found; skipping Drools persistence cleanup" >&2
    return 0
  fi

  local rc=0
  oc --context="${OCP_CONTEXT}" -n "${EDA_PG_NAMESPACE}" exec "${EDA_PG_POD}" -- \
    psql -U eda -d eda -v ON_ERROR_STOP=1 -c \
    "DELETE FROM drools_ansible_matching_event WHERE ha_uuid='${activation_id}';
     DELETE FROM drools_ansible_session_state WHERE ha_uuid='${activation_id}';
     DELETE FROM drools_ansible_ha_stats WHERE ha_uuid='${activation_id}';" \
    >/dev/null 2>&1 || rc=$?
  if [[ "${rc}" -ne 0 ]]; then
    echo "    WARN: could not clear Drools persistence for activation ${activation_id}" >&2
    return 1
  fi
  echo "    cleared Drools persistence tables for activation id=${activation_id}" >&2
  sleep 3
}

eda_persist_wait_webhook_ready() {
  local webhook_url="${1:?webhook url}"
  local deadline=$((SECONDS + ${2:-120}))
  local code="000"

  while (( SECONDS < deadline )); do
    code=$(eda_persist_post_event "${webhook_url}" \
      '{"event_type":"threshold-reset","batch_id":"__healthcheck__"}')
    if [[ "${code}" == "200" ]]; then
      sleep 3
      return 0
    fi
    if [[ "${code}" =~ ^(502|503|504)$ ]]; then
      echo "    webhook HTTP ${code}, waiting..." >&2
      sleep 5
      continue
    fi
    echo "FAILED: Webhook probe returned HTTP ${code}" >&2
    return 1
  done

  echo "FAILED: Webhook not ready after ${2:-120}s (last HTTP ${code})" >&2
  return 1
}

eda_persist_wait_webhook_up() {
  local webhook_url="${1:?webhook url}"
  local deadline=$((SECONDS + ${2:-180}))
  local code="000"

  while (( SECONDS < deadline )); do
    code=$(curl -sk --max-time 10 -o /dev/null -w "%{http_code}" \
      -X POST "${webhook_url}" \
      -H "Content-Type: application/json" \
      -d '{"event_type":"threshold-reset","batch_id":"__healthcheck__"}')
    if [[ "${code}" == "200" ]]; then
      return 0
    fi
    if [[ "${code}" =~ ^(502|503|504)$ ]]; then
      echo "    webhook HTTP ${code}, waiting..." >&2
      sleep 5
      continue
    fi
    echo "FAILED: Webhook probe returned HTTP ${code}" >&2
    return 1
  done

  echo "FAILED: Webhook not ready after ${2:-180}s (last HTTP ${code})" >&2
  return 1
}

eda_persist_ensure_ready() {
  local activation_name="${1:?activation name}"
  local webhook_url="${2:?webhook url}"
  local deadline=$((SECONDS + ${3:-240}))

  eda_persist_wait_running "${activation_name}" $((deadline - SECONDS)) || return 1
  eda_persist_wait_webhook_ready "${webhook_url}" $((deadline - SECONDS))
}

eda_persist_prepare_clean_activation() {
  local activation_name="${1:?activation name}"
  local webhook_url="${2:?webhook url}"
  local deadline=$((SECONDS + ${3:-300}))
  local activation_id

  activation_id=$(eda_persist_activation_id "${activation_name}")
  if [[ -z "${activation_id}" ]]; then
    echo "FAILED: Activation ${activation_name} not found" >&2
    return 1
  fi

  echo "    clearing stale Drools persistence state..." >&2
  eda_persist_clear_session_state "${activation_id}" || true
  eda_persist_restart_activation "${activation_name}"
  sleep 5
  eda_persist_wait_running "${activation_name}" $((deadline - SECONDS)) || return 1
  echo "    waiting for activation webhook after restart..." >&2
  eda_persist_wait_webhook_up "${webhook_url}" $((deadline - SECONDS)) || return 1
  sleep 15
}

eda_persist_wait_listening() {
  local activation_name="${1:?activation name}"
  local deadline=$((SECONDS + ${2:-180}))

  while (( SECONDS < deadline )); do
    local act_id inst_id ready
    act_id=$(eda_persist_activation_id "${activation_name}")
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
    ready=$(curl -sk "${AUTH[@]}" "${EDA_API}/activation-instances/${inst_id}/logs/?page_size=30" \
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
page_size = 30
data = fetch(f'{api}?page_size={page_size}')
count = data.get('count', 0) or 0
last_page = max(1, (count + page_size - 1) // page_size)
text = ''
for page in range(max(1, last_page - 2), last_page + 1):
    try:
        chunk = fetch(f'{api}?page={page}&page_size={page_size}')
    except Exception:
        continue
    text += '\n'.join(r.get('log', '') for r in chunk.get('results', []))
markers = [l for l in text.splitlines() if (
    'Waiting for events, ruleset:' in l
    or 'Waiting for actions on events from' in l
    or 'MATCHING_EVENT_RECOVERY' in l
)]
if not markers:
    print('')
elif 'Waiting for events, ruleset:' in markers[-1]:
    print('ready')
else:
    print('recovering')
")
    if [[ "${ready}" == "ready" ]]; then
      return 0
    fi
    if [[ "${ready}" == "recovering" ]]; then
      echo "    waiting for persistence replay to finish (instance=${inst_id})..." >&2
    else
      echo "    waiting for webhook listener (instance=${inst_id})..." >&2
    fi
    sleep 5
  done

  echo "FAILED: Activation ${activation_name} webhook not listening after ${2:-180}s" >&2
  return 1
}

eda_persist_ts() {
  date +%s
}

eda_persist_post_event() {
  local webhook_url="${1:?url}"
  local payload="${2:?json payload}"
  local http_code
  http_code=$(curl -sk --max-time 15 -o /tmp/eda-persist-webhook-body.txt -w "%{http_code}" \
    -X POST "${webhook_url}" \
    -H "Content-Type: application/json" \
    -d "${payload}")
  echo "${http_code}"
}

eda_persist_post_event_retry() {
  local webhook_url="${1:?url}"
  local payload="${2:?json payload}"
  local deadline=$((SECONDS + ${3:-90}))
  local code="000"

  while (( SECONDS < deadline )); do
    code=$(eda_persist_post_event "${webhook_url}" "${payload}")
    if [[ "${code}" == "200" ]]; then
      echo "${code}"
      return 0
    fi
    if [[ "${code}" =~ ^(502|503|504)$ ]]; then
      echo "    webhook HTTP ${code}, retrying..." >&2
      sleep 5
      continue
    fi
    echo "${code}"
    return 1
  done

  echo "${code}"
  return 1
}

eda_persist_instance_log_count() {
  local inst_id="${1:?instance id}"
  curl -sk "${AUTH[@]}" "${EDA_API}/activation-instances/${inst_id}/logs/?page_size=1" \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('count',0))"
}

eda_persist_wait_ruleset_idle() {
  local activation_name="${1:?activation name}"
  local min_log_count="${2:-0}"
  local expected_rule="${3:-}"
  local deadline=$((SECONDS + ${4:-90}))

  while (( SECONDS < deadline )); do
    local act_id inst_id state log_count
    act_id=$(eda_persist_activation_id "${activation_name}")
    inst_id=$(curl -sk "${AUTH[@]}" \
      "${EDA_API}/activation-instances/?activation_id=${act_id}&order_by=-id&page_size=1" \
      | python3 -c "import json,sys; r=json.load(sys.stdin).get('results',[]); print(r[0]['id'] if r else '')")
    if [[ -z "${inst_id}" ]]; then
      sleep 2
      continue
    fi
    log_count=$(eda_persist_instance_log_count "${inst_id}")
    if [[ "${log_count}" -le "${min_log_count}" ]]; then
      echo "    waiting for ruleset activity (logs=${log_count})..." >&2
      sleep 2
      continue
    fi
    state=$(curl -sk "${AUTH[@]}" "${EDA_API}/activation-instances/${inst_id}/logs/?page_size=40" \
      | python3 -c "
import json, sys, urllib.request, base64, os
inst_id = '${inst_id}'
expected_rule = '''${expected_rule}'''
api = '${EDA_API}/activation-instances/' + inst_id + '/logs/'
auth = base64.b64encode(f\"{os.environ.get('AAP_USER','admin')}:{os.environ['AAP_PASS']}\".encode()).decode()
def fetch(url):
    req = urllib.request.Request(url, headers={'Authorization': f'Basic {auth}'})
    ctx = urllib.request.ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = 0
    with urllib.request.urlopen(req, context=ctx) as resp:
        return json.load(resp)
page_size = 40
data = fetch(f'{api}?page_size={page_size}')
total = data.get('count', 0) or 0
last_page = max(1, (total + page_size - 1) // page_size)
text = ''
for page in range(max(1, last_page - 1), last_page + 1):
    try:
        chunk = fetch(f'{api}?page={page}&page_size={page_size}')
    except Exception:
        continue
    text += '\n'.join(r.get('log', '') for r in chunk.get('results', []))
markers = [l for l in text.splitlines() if 'finished, active actions 0' in l]
if expected_rule and expected_rule not in text:
    print('')
    raise SystemExit
if not markers:
    print('')
    raise SystemExit
print('idle')
")
    if [[ "${state}" == "idle" ]]; then
      return 0
    fi
    echo "    waiting for ruleset to become idle..." >&2
    sleep 2
  done

  echo "FAILED: ruleset not idle within ${4:-90}s" >&2
  return 1
}

eda_persist_wait_fact() {
  local activation_name="${1:?activation name}"
  local threshold_count="${2:?count}"
  local batch_id="${3:-}"
  local deadline=$((SECONDS + ${4:-90}))

  while (( SECONDS < deadline )); do
    local act_id inst_id found
    act_id=$(eda_persist_activation_id "${activation_name}")
    inst_id=$(curl -sk "${AUTH[@]}" \
      "${EDA_API}/activation-instances/?activation_id=${act_id}&order_by=-id&page_size=1" \
      | python3 -c "import json,sys; r=json.load(sys.stdin).get('results',[]); print(r[0]['id'] if r else '')")
    if [[ -z "${inst_id}" ]]; then
      sleep 2
      continue
    fi
    found=$(curl -sk "${AUTH[@]}" "${EDA_API}/activation-instances/${inst_id}/logs/?page_size=40" \
      | python3 -c "
import json, sys, urllib.request, base64, os
inst_id = '${inst_id}'
count_want = '${threshold_count}'
batch_id = '${batch_id}'
api = '${EDA_API}/activation-instances/' + inst_id + '/logs/'
auth = base64.b64encode(f\"{os.environ.get('AAP_USER','admin')}:{os.environ['AAP_PASS']}\".encode()).decode()
def fetch(url):
    req = urllib.request.Request(url, headers={'Authorization': f'Basic {auth}'})
    ctx = urllib.request.ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = 0
    with urllib.request.urlopen(req, context=ctx) as resp:
        return json.load(resp)
page_size = 40
data = fetch(f'{api}?page_size={page_size}')
last_page = max(1, (data.get('count', 0) + page_size - 1) // page_size)
needle_single = f\"'threshold_count': {count_want}\"
needle_json = f'\"threshold_count\": {count_want}'
text = ''
for page in range(max(1, last_page - 2), last_page + 1):
    try:
        chunk = fetch(f'{api}?page={page}&page_size={page_size}')
    except Exception:
        continue
    text += '\n'.join(r.get('log', '') for r in chunk.get('results', []))
if needle_single not in text and needle_json not in text:
    print('')
    raise SystemExit
if batch_id and batch_id not in text:
    print('')
    raise SystemExit
print('ok')
")
    if [[ "${found}" == "ok" ]]; then
      return 0
    fi
    echo "    waiting for threshold_count=${threshold_count}..." >&2
    sleep 2
  done

  echo "FAILED: threshold_count=${threshold_count} not observed within ${4:-90}s" >&2
  return 1
}

eda_persist_send_reset() {
  local webhook_url="${1:?url}"
  local batch_id="${2:?batch}"
  local activation_name="${3:-}"
  eda_persist_post_event_retry "${webhook_url}" \
    "{\"event_type\":\"threshold-reset\",\"batch_id\":\"${batch_id}\"}" 60 >/dev/null
  if [[ -n "${activation_name}" ]]; then
    sleep 15
  else
    sleep 3
  fi
}

eda_persist_send_hit() {
  local webhook_url="${1:?url}"
  local batch_id="${2:?batch}"
  local seq="${3:?1-3}"
  local activation_name="${4:-}"
  local ts code
  ts=$(eda_persist_ts)
  code=$(eda_persist_post_event_retry "${webhook_url}" \
    "{\"event_type\":\"threshold-hit\",\"batch_id\":\"${batch_id}\",\"hit_seq\":${seq},\"ts\":${ts}}" 90)
  if [[ "${code}" == "200" && -n "${activation_name}" ]]; then
    sleep 10
  fi
  echo "${code}"
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
