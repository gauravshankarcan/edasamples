# EDA Event Persistence (AAP 2.7+)

## What this sample demonstrates

**State preservation** — `enable_persistence` saves the Drools rule engine’s
internal facts to Postgres so they survive activation restarts.

### Use case: 3 events within 10 minutes

The rulebook counts `threshold-hit` webhook events in `facts.threshold_count`.
A Controller job runs only when the counter reaches **3** inside a **10-minute**
window (`facts.window_started_at`).

| Without persistence | With persistence |
|---------------------|------------------|
| Restart clears `threshold_count` | Restart restores count from Postgres |
| After 2 hits + restart, hit #3 starts at 1 | After 2 hits + restart, hit #3 reaches 3 → job fires |

This is **not** about keeping a Controller job alive (Controller runs jobs
independently). It is about **rule engine memory** — counts, windows, and other
facts Drools uses to decide when to act.

| Setting | Purpose |
|---------|---------|
| `enable_persistence` | Persist Drools facts across activation restarts |
| `rule_engine_credential` | Postgres credential for the rule engine |
| `restart_on_project_update` | Often paired with persistence during reloads |

---

## Files

```
eda_event_persistence/
├── README.md
├── setup_aap.yml
└── playbooks/
    └── persistence_action.yml    ← Runs when 3 hits threshold is met

rulebooks/
└── eda-event-persistence.yml     ← Counter + 10-minute window rules
```

---

## How it works

```
Hit 1 → facts.threshold_count = 1
Hit 2 → facts.threshold_count = 2
        [activation restart — facts lost unless persistence]
Hit 3 → facts.threshold_count = 3 → run_job_template
```

Webhook payloads:

| event_type | Purpose |
|------------|---------|
| `threshold-reset` | Clear counter (start of each test) |
| `threshold-hit` | Count one hit; include `ts` (unix seconds) and `batch_id` |

---

## Prerequisites

1. **EDA-Persistence-DE** — for `--persistence-id` when persistence is enabled.
2. **Rule Engine credential** — created by `setup_aap.yml` from cluster Postgres.
3. **CRC route** — `oc --context=crc-admin get route eda-event-persistence-activation -n aap`
4. **EDA 2.7+ server** — required for `enable_persistence: true` (2.6 → websocket 1011).

## Setup

```bash
source ~/.bashrc_eda_session
export KUBECONFIG=~/.kube/config
ansible-playbook eda_event_persistence/setup_aap.yml
```

---

## Tests

### Test 29 — smoke (no job until 3 hits)

```bash
bash testcases/29_event_persistence_send.sh
```

Resets counter, sends **1** hit, verifies HTTP 200 and **no** Controller job.

### Test 30 — state survives restart (requires `enable_persistence`)

```bash
bash testcases/30_event_persistence_restart_verify.sh
```

1. Reset, send hits **1** and **2**
2. Restart activation
3. Send hit **3** → job must fire if persistence preserved the count

Exits with code **2** (skip) if `enable_persistence` is false.

### Manual

```bash
BATCH="manual-$(date +%s)"
TS=$(date +%s)
curl -sk -X POST https://eda-event-persistence-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d "{\"event_type\":\"threshold-reset\",\"batch_id\":\"$BATCH\"}"
for i in 1 2 3; do
  curl -sk -X POST https://eda-event-persistence-activation.apps-crc.testing \
    -H "Content-Type: application/json" \
    -d "{\"event_type\":\"threshold-hit\",\"batch_id\":\"$BATCH\",\"hit_seq\":$i,\"ts\":$TS}"
  sleep 1
done
# After 3rd hit: AAP → Jobs → EDA-Event-Persistence-Action
```

---

## References

- [AAP 2.7 — enable event persistence](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/html/administering_automation_decisions/eda-rulebook-activations)
- [best_practice/samples/02_stateful_facts.yml](../best_practice/samples/02_stateful_facts.yml) — `set_fact` counting pattern
