# EDA Best Practices — For Ansible Playbook Users

This guide bridges the gap between traditional `ansible-playbook` knowledge and
Event-Driven Ansible (EDA). It explains every EDA concept by mapping it to its
closest playbook equivalent, then covers project layout, naming, testing, and
lifecycle management.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Rulebook Anatomy — Mapped to Playbook Concepts](#2-rulebook-anatomy)
3. [Events vs Facts vs Variables](#3-events-vs-facts-vs-variables)
4. [Condition Syntax Cheat-Sheet](#4-condition-syntax)
5. [Available Actions](#5-available-actions)
6. [Decision Environment vs Execution Environment](#6-decision-environment-vs-execution-environment)
7. [Project Directory Structure](#7-project-directory-structure)
8. [Naming Conventions](#8-naming-conventions)
9. [Secret Management](#9-secret-management)
10. [Testing Strategies](#10-testing-strategies)
11. [Annotated Sample Rulebooks](#11-annotated-sample-rulebooks)

---

## 1. Architecture Overview

```
Traditional Ansible (you trigger it):
  Operator → ansible-playbook site.yml → Managed Hosts

Event-Driven Ansible (events trigger it):
  External System → Event Source → Rulebook → Action → Managed Hosts
                                      ↕
                              Rules Engine (Drools)
                              holds working memory (facts)
```

| Traditional Ansible | EDA Equivalent | Notes |
|---|---|---|
| `ansible-playbook` CLI | `ansible-rulebook` CLI | Different binary, different image |
| Execution Environment (EE) | Decision Environment (DE) | DE contains `ansible-rulebook` |
| `site.yml` playbook file | Rulebook file | YAML but different structure |
| Play | Rule | Within a rulebook |
| `hosts:` in a play | `sources:` in a rulebook | Where data comes _from_ |
| `tasks:` list | `rules:` list | What to evaluate/do |
| `when:` condition | `condition:` in a rule | When to fire |
| `register` variable | `set_fact` action | Persist data |
| `ansible_facts` (host data) | `event.` (event data) | Completely different concept! |
| `vars:` in playbook | `vars:` in rulebook | Works similarly |

---

## 2. Rulebook Anatomy

```yaml
---
# ─── TOP LEVEL: list of rulesets ───────────────────────────────────────────
- name: "My Ruleset"                   # ← Like a "play" name in a playbook

  # SOURCES: where events come from (no playbook equivalent – this replaces
  # the "hosts:" concept for EDA. The rulebook REACTS to these, it doesn't
  # connect TO them the way a play connects to hosts.)
  sources:
    - ansible.eda.webhook:             # Source plugin (like a connection plugin)
        host: 0.0.0.0
        port: 5000
      filters:                         # Optional: transform/filter events before rules see them
        - ansible.eda.json_filter:
            include_keys:
              - payload
              - meta

  # VARS: static variables available to all rules in this ruleset
  vars:
    environment: "production"
    notify_channel: "#ops-alerts"

  # RULES: evaluated against every incoming event (like tasks, but conditional)
  rules:
    - name: "Handle deployment event"   # ← Descriptive, like a task name

      # CONDITION: evaluated by the rules engine.
      # IMPORTANT: This is NOT Jinja2! It is a Drools-like DSL.
      # Syntax differences vs playbook "when:":
      #   Playbook: when: item == "value"        (Python comparison)
      #   EDA:      condition: event.field == "value"  (Drools DSL, same operators)
      condition: >
        event.payload.status == "deploy" and
        event.payload.environment == vars.environment

      # ACTION: what to do when condition matches
      action:
        run_job_template:              # Calls AAP Controller job template
          name: "Deploy Application"
          organization: "Default"
          job_args:
            extra_vars:
              deploy_version: "{{ event.payload.version }}"
              target_env: "{{ event.payload.environment }}"
```

### The `hosts:` field in a rulebook

Coming from playbooks, `hosts:` in a rulebook is confusing. It is **NOT** the
list of managed hosts to connect to. Instead, it is passed to any `run_playbook`
action as the target hosts. For `run_job_template`, the job template's own
inventory is used — the rulebook `hosts:` is irrelevant.

```yaml
- name: "My Ruleset"
  hosts: all     # ← Passed to run_playbook actions only. Ignored by run_job_template.
  sources: [...]
  rules: [...]
```

---

## 3. Events vs Facts vs Variables

This is the **most commonly confused** area for playbook users.

### 3a. Events (`event.`)

- Incoming data from an event source (webhook payload, Kafka message, etc.)
- **Ephemeral** — available only within the rule being evaluated
- Accessed as `event.<field>` in conditions and action templates
- Each event is a single dict; multiple events create multiple evaluation cycles

```yaml
# A webhook POST with body: {"status": "ok", "host": "web01"}
# Accessed in condition as:
condition: event.payload.status == "ok"
# Accessed in action as:
action:
  run_playbook:
    name: playbooks/fix.yml
    extra_vars:
      target_host: "{{ event.payload.host }}"
```

### 3b. EDA Facts (`facts.` or via `set_fact`)

- Key-value pairs stored in the **rules engine working memory**
- **Persistent** across events within the same activation session
- Set with the `set_fact` action, accessed as `facts.<key>` in conditions
- **NOT** the same as `ansible_facts` from the `setup` module!

```yaml
rules:
  - name: "Count alerts"
    condition: event.payload.level == "warning"
    action:
      set_fact:
        alert_count: "{{ (facts.alert_count | default(0) | int) + 1 }}"

  - name: "Escalate after 3 warnings"
    condition: facts.alert_count >= 3
    action:
      run_job_template:
        name: "Escalate Alert"
        organization: "Default"
```

### 3c. Ansible Host Facts (`ansible_facts`)

- Gathered by `setup` module on managed hosts during a playbook run
- **Only exist inside a playbook** triggered by EDA — never visible to the rulebook
- EDA has no concept of `gather_facts`

### 3d. Rulebook Variables (`vars.`)

- Static values defined in the rulebook `vars:` section
- Available in conditions: `vars.my_var`
- Available in action templates: `{{ vars.my_var }}`

### Summary Table

| Name | Where Set | Where Accessed | Lifetime | Equivalent |
|---|---|---|---|---|
| `event.*` | Event source | Condition, action template | One rule evaluation | Like `ansible_facts` but per-event |
| `facts.*` | `set_fact` action | Condition, action template | Entire activation | Like `register` but persistent |
| `vars.*` | `vars:` in rulebook | Conditions + templates | Entire activation | Like `group_vars` |
| `ansible_facts` | `setup` module | Playbook tasks only | One playbook run | N/A to rulebook |

---

## 4. Condition Syntax

EDA conditions use a Drools-like DSL, not Jinja2 or Python.

```yaml
# Simple equality
condition: event.payload.status == "ok"

# AND / OR
condition: >
  event.payload.level == "critical" and
  event.payload.environment == "production"

# OR with parentheses
condition: >
  (event.payload.action == "create" or event.payload.action == "update") and
  event.payload.resource == "vm"

# Check if a key exists
condition: event.payload.host is defined

# Numeric comparison
condition: event.payload.cpu_percent > 80

# String contains (use regex)
condition: event.payload.message is match(".*ERROR.*")

# Access nested dicts
condition: event.payload.metadata.environment == "prod"

# Access facts (persistent state)
condition: facts.alert_count >= 5

# Access rulebook vars
condition: event.payload.env == vars.target_env

# Multiple conditions — all must match (AND semantics with multiple conditions:)
condition:
  all:
    - event.payload.status == "error"
    - event.payload.priority == "high"

# Any must match (OR semantics):
condition:
  any:
    - event.payload.status == "critical"
    - event.payload.priority == "emergency"
```

### Common Gotchas

```yaml
# WRONG: using Jinja2 test syntax
condition: event.payload.status is == "ok"   # invalid

# WRONG: using Python 'in' operator
condition: "error" in event.payload.message  # invalid

# RIGHT:
condition: event.payload.message is search("error")

# WRONG: trying to access ansible_facts in condition
condition: ansible_facts.os_family == "RedHat"  # ansible_facts don't exist here

# RIGHT: pass what you need in the event payload or set_fact first
condition: facts.os_family == "RedHat"
```

---

## 5. Available Actions

| Action | Playbook Equivalent | When to Use |
|---|---|---|
| `run_job_template:` | External trigger | Main action for AAP-integrated EDA |
| `run_workflow_template:` | External trigger | Multi-playbook orchestration |
| `run_playbook:` | `ansible-playbook` | Local playbooks inside DE image |
| `set_fact:` | `set_fact` task | Persist state across events |
| `post_event:` | N/A | Publish a new event (self-trigger) |
| `debug:` | `debug:` task | Log a message (dev/testing) |
| `print_event:` | `debug: var=item` | Print the full event |
| `none:` | N/A | No-op (useful for testing conditions) |
| `shutdown:` | N/A | Stop the rulebook activation |

```yaml
# run_job_template — most common production action
action:
  run_job_template:
    name: "My Job Template"          # Must exist in AAP Controller
    organization: "Default"
    job_args:
      extra_vars:                    # Passed to job template
        event_host: "{{ event.payload.host }}"
      limit: "{{ event.payload.host }}"    # Limit job to specific hosts
      tags: "provision"              # Run only tagged tasks

# set_fact — building state machines
action:
  set_fact:
    incident_id: "{{ event.payload.id }}"
    incident_start_time: "{{ event.meta.received_at }}"

# post_event — chaining rules
action:
  post_event:
    event:
      my_custom_event:
        status: "processed"
        original_id: "{{ event.payload.id }}"
```

---

## 6. Decision Environment vs Execution Environment

Both are OCI container images. The key difference:

| | Execution Environment (EE) | Decision Environment (DE) |
|---|---|---|
| **Runs** | `ansible-playbook` | `ansible-rulebook` |
| **Contains** | `ansible-core`, collections, Python | `ansible-rulebook`, event source plugins, collections |
| **Base image** | `ee-minimal` or `ee-supported` | `de-minimal` or `de-supported` |
| **Built with** | `ansible-builder` | `ansible-builder` (same tool) |
| **Used in** | Job Templates | Rulebook Activations |
| **Config file** | `execution-environment.yml` | `execution-environment.yml` (type: DecisionEnvironment) |

```
AAP Controller uses EE → runs playbooks
AAP EDA Controller uses DE → runs rulebooks
```

A single DE typically includes:
- `ansible-rulebook` (the EDA engine)
- Event source collections (`ansible.eda`, `community.aws`, etc.)
- Any collections needed by triggered playbooks (if using `run_playbook`)
- Python dependencies for source plugins

---

## 7. Project Directory Structure

> **AAP EDA Requirement**: AAP EDA Controller will only pick up rulebooks from
> a top-level `rulebooks/` directory (or `extensions/eda/rulebooks/` for
> collection-style layout). Rulebooks located in subdirectories are invisible
> to EDA project imports. Always put the actual `.yml` rulebook files that
> need to be activatable in `rulebooks/` at the project root.

```
my-eda-project/
├── README.md
├── .gitignore
│
├── rulebooks/                   # ← REQUIRED: AAP EDA picks up from here
│   ├── samples-webhook.yml
│   ├── eda-param-deploy.yml
│   ├── eda-limit-jobs.yml
│   └── eda-requestor.yml
│
├── decision-environment/        # DE build artifacts
│   ├── Containerfile            # OCI build file
│   ├── execution-environment.yml
│   ├── requirements.yml         # Collections
│   └── requirements.txt         # Python packages
│
├── rulebooks/                   # All rulebooks go here
│   ├── webhook_deploy.yml
│   ├── aws_alerts.yml
│   └── maintenance_window.yml
│
├── playbooks/                   # Playbooks called by run_playbook (local execution)
│   ├── handle_deploy.yml
│   └── common/
│       └── notify.yml
│
├── inventory/                   # Static inventories (for run_playbook actions)
│   ├── production/
│   │   └── hosts.yml
│   └── staging/
│       └── hosts.yml
│
├── vars/                        # Shared variable files
│   ├── production.yml
│   └── staging.yml
│
└── tests/                       # Testing scripts
    ├── test_webhook_deploy.sh   # Curl-based trigger tests
    └── expected_events/
        └── deploy_event.json
```

---

## 8. Naming Conventions

### Rulebook Files
```
<source-type>_<domain>_<environment>.yml
webhook_deployments_prod.yml
kafka_alerts_staging.yml
aws_autoscaling_prod.yml
```

### Rule Names (inside rulebook)
```
[action] [object] [condition]
"Escalate high-priority deployment failure"
"Notify on database CPU exceeding threshold"
"Provision VM on scale-out event"
```

### Fact Keys
Use namespacing to avoid collisions:
```yaml
set_fact:
  deploy_incident_id: "{{ event.payload.id }}"      # ← good: namespaced
  id: "{{ event.payload.id }}"                      # ← bad: too generic
```

### Job Template Names in AAP
Prefix with `EDA-` so they're easily identified as EDA-triggered:
```
EDA-Deploy-Application
EDA-Scale-Out-VM
EDA-Remediate-Disk-Alert
```

---

## 9. Secret Management

Never put credentials in rulebooks. Use AAP EDA Credentials:

```yaml
# BAD — credentials in rulebook
sources:
  - ansible.eda.aws_sqs_queue:
      name: "my-queue"
      access_key: "AKIA..."          # ← NEVER do this
      secret_key: "secret..."

# GOOD — reference EDA credential (configured in AAP EDA UI)
sources:
  - ansible.eda.aws_sqs_queue:
      name: "my-queue"
      region: "us-east-1"
      # Credentials injected at activation time via EDA Credential object
```

For environment variables in rulebooks:
```yaml
vars:
  environment: "{{ EDA_ENV | default('staging') }}"   # From activation extra-vars
```

---

## 10. Testing Strategies

### Local Testing (outside AAP)
```bash
# Install locally (uses your local Python venv)
pip install ansible-rulebook ansible-runner

# Run a rulebook locally
ansible-rulebook --rulebook rulebooks/webhook_deploy.yml \
  --inventory inventory/staging/hosts.yml \
  --env-var AWS_ACCESS_KEY_ID \
  --env-var AWS_SECRET_ACCESS_KEY \
  -v

# Trigger webhook in another terminal
curl -X POST http://localhost:5000 \
  -H "Content-Type: application/json" \
  -d '{"payload": {"status": "deploy", "version": "1.2.3"}}'
```

### Condition Testing
Use `debug:` action first to verify conditions match:
```yaml
rules:
  - name: "DEBUG: Check event structure"    # ← Temporary debug rule
    condition: event.payload is defined
    action:
      debug:
        msg: "Event received: {{ event }}"

  - name: "Real action — remove debug above when confirmed"
    condition: event.payload.status == "deploy"
    action:
      run_job_template:
        name: "EDA-Deploy-Application"
        organization: "Default"
```

### Integration Testing
```bash
# test_webhook.sh — included in tests/ folder
WEBHOOK_URL="https://your-eda-server:5000"
CORRELATION_ID=$(uuidgen)

curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-ID: $CORRELATION_ID" \
  -d '{
    "payload": {
      "status": "deploy",
      "version": "1.2.3",
      "environment": "staging",
      "correlation_id": "'"$CORRELATION_ID"'"
    }
  }'

echo "Check AAP for job triggered by correlation_id: $CORRELATION_ID"
```

---

## 11. Annotated Sample Rulebooks

See the `samples/` directory in this repository for:

- `samples/` — Basic webhook → job template
- `eda_param_samples/` — Webhook with parameterized extra vars
- `eda_param_limit_jobs/` — Job template with host limiting
- `eda_requestor/` — Response-back-to-requester pattern

Each sample includes a `README.md` with:
- What the sample demonstrates
- How to configure it in AAP
- How to test it
- Common errors and solutions
