# EDA Event Persistence (AAP 2.7+)

## What this sample demonstrates

**Event persistence** is a new AAP 2.7 activation option that saves in-flight event
state to the database so processing can resume without data loss after an activation
restart. This is especially important when **Auto-restart on project update** is
enabled, because it prevents event gaps while the activation reloads updated rulebooks.

| Setting | Purpose |
|---------|---------|
| `enable_persistence` | Persist in-flight events across activation restarts |
| `restart_on_project_update` | Auto-restart when the EDA project syncs new rulebook content |
| `rule_engine_credential` | Optional Postgres credential for the Drools rule engine (defaults to the system credential) |

Without persistence, events that arrive while a long-running action is in progress
can be lost if the activation pod restarts mid-flight.

---

## Files

```
eda_event_persistence/
├── README.md                     ← This file
├── rulebook.yml                  ← Local reference copy
├── setup_aap.yml                 ← Creates AAP Controller + EDA objects
└── playbooks/
    └── persistence_action.yml    ← 30s sleep to allow restart mid-flight

rulebooks/
└── eda-event-persistence.yml     ← AAP-activatable version
```

---

## How persistence works

```
Time→   0s              5s (restart)        30s
        │                │                   │
Event   ├──[rule fires]──┤ activation dies     │
        │   job starts   │ persistence saves   │
        │                │ activation restarts │
        │                ├──[resume event]────►│ job completes
```

1. A webhook event triggers `run_job_template` (a 30-second playbook).
2. While the job is running, restart the activation (or let project auto-restart fire).
3. With `enable_persistence: true`, the Drools engine restores the in-flight event
   and the job completes.
4. Without persistence, the event is lost and no job finishes.

Persistence uses the **Event-Driven Ansible Rule Engine** credential (Postgres).
If you do not select one in the UI, AAP uses the **System Event-Driven Ansible Rule
Engine Credential** automatically.

---

## Configure in AAP

### Via the UI (Automation Decisions → Rulebook Activations)

1. Create or edit a rulebook activation.
2. Under **Options**, check **Enable event persistence**.
3. Optionally select an **Event-Driven Ansible Rule Engine** credential.
4. Optionally check **Auto-restart on project update** (pairs well with persistence).

### Via `ansible.eda.rulebook_activation`

```yaml
ansible.eda.rulebook_activation:
  name: eda-event-persistence-activation
  project: EDA-Samples
  rulebook: eda-event-persistence.yml
  decision_environment: EDA-Community-DE
  enable_persistence: true
  restart_on_project_update: true
  restart_policy: never
  eda_credentials:
    - EDA-AAP-Controller-Credential
  state: present
```

### Via the EDA API

```json
POST /api/eda/v1/activations/
{
  "name": "eda-event-persistence-activation",
  "enable_persistence": true,
  "restart_on_project_update": true,
  "rulebook_rulesets": "rulebooks/eda-event-persistence.yml",
  ...
}
```

---

## Setup

```bash
source ~/.bashrc_eda_session
ansible-playbook eda_event_persistence/setup_aap.yml
```

Or deploy everything via the main config:

```bash
ansible-playbook aap_config/configure_aap.yml -e @aap_config/vault.yml
```

---

## Test — restart while event is in-flight

### Step 1: Send a long-running event

```bash
bash testcases/29_event_persistence_send.sh
```

This POSTs an event with a 30-second job. The activation has `enable_persistence: true`.

### Step 2: Restart activation and verify job completes

```bash
bash testcases/30_event_persistence_restart_verify.sh
```

This script:
1. Sends the long-running event
2. Waits 3 seconds (job is running, event is in-flight)
3. Restarts the activation via the EDA API
4. Polls AAP Controller until `EDA-Event-Persistence-Action` succeeds for `EVT-PERSIST-001`

### Manual test

```bash
# Send event (30s job)
curl -kv -X POST https://eda-event-persistence-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"persist-test","event_id":"EVT-PERSIST-001","sleep_seconds":30}'

# Wait a few seconds, then restart activation in AAP UI or:
curl -sk -u admin:$AAP_PASS -X POST \
  "$AAP_BASE/api/eda/v1/activations/<ID>/restart/"

# Verify in AAP → Jobs: EDA-Event-Persistence-Action should reach Successful
```

---

## Related AAP 2.7 features

| Feature | Relationship |
|---------|-------------|
| Auto-restart on project update | Restarts activations after project sync; persistence prevents event loss during restart |
| Execution strategy | Orthogonal — controls concurrent event processing, not restart survival |
| Log tracking ID | Helps trace activation lifecycle across restarts in logs |

---

## References

- [AAP 2.7 — Rulebook activations (enable event persistence)](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/html/administering_automation_decisions/eda-rulebook-activations)
- [ansible.eda.rulebook_activation — enable_persistence](https://docs.ansible.com/projects/ansible-eda/rulebook_activation_module.html)
- [ansible-rulebook in-flight event persistence PR #896](https://github.com/ansible/ansible-rulebook/pull/896)
