# EDA Parameterized Input — Webhook with Extra Vars

Demonstrates the full flow of parameterizing EDA automation via webhook payload.

## The Core Pattern

```
Webhook POST (with structured payload)
    ↓
EDA Condition (match on action type)
    ↓
run_job_template (map event fields → extra_vars)
    ↓
AAP Job Template (ask_variables_on_launch: true)
    ↓
Playbook (uses vars: defaults + extra_vars override)
```

## Variable Flow Explained

This is the most important concept for playbook users moving to EDA:

```yaml
# 1. Webhook payload arrives (JSON POST body)
{
  "action": "deploy",
  "service": "payment-api",
  "version": "2.3.1",
  "environment": "staging"
}

# 2. EDA rulebook condition matches
condition: event.payload.action == "deploy"

# 3. EDA maps event fields to extra_vars
action:
  run_job_template:
    job_args:
      extra_vars:
        param_service: "{{ event.payload.service }}"  # → "payment-api"
        param_version: "{{ event.payload.version }}"  # → "2.3.1"

# 4. Job template launches playbook with those extra_vars
# playbook receives: param_service="payment-api", param_version="2.3.1"

# 5. Playbook uses them
- name: "Deploy"
  debug:
    msg: "Deploying {{ param_service }} {{ param_version }}"
```

## Supported Actions

| Action | Required Fields | Optional Fields |
|---|---|---|
| `deploy` | `service`, `version` | `environment`, `requestor`, `ticket_id` |
| `rollback` | `service`, `version` | `environment`, `requestor`, `ticket_id` |
| `restart` | `service` | `environment`, `requestor` |
| `scale` | `service`, `replicas` | `environment`, `requestor` |

## Setup

```bash
export AAP_BASE="https://aap-aap.apps-crc.testing"
export AAP_TOKEN="<gateway-token>"
ansible-playbook eda_param_samples/setup_aap.yml
```

## Test Examples

```bash
WEBHOOK_URL="http://localhost:5000"  # Get from activation

# Deploy
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "deploy",
    "service": "payment-api",
    "environment": "staging",
    "version": "2.3.1",
    "requestor": "john.doe@example.com",
    "ticket_id": "JIRA-4567"
  }'

# Scale
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "scale",
    "service": "web-frontend",
    "environment": "production",
    "replicas": 5,
    "requestor": "ops-team"
  }'

# Invalid action (should be rejected by EDA)
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"action": "delete", "service": "critical-db"}'
```

## Best Practices for Extra Vars

1. **Always provide defaults in the playbook** — EDA may not always send every field
2. **Validate in the playbook** — Use `assert` to fail early with clear messages  
3. **Audit trail** — Always write a record of what was triggered and by whom
4. **Prefix vars** — Use `param_` prefix for EDA-passed vars to avoid collision with Ansible built-in vars
5. **Never pass secrets in event payload** — Use credential objects in AAP instead
