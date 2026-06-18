# EDA Sample: Webhook → Job Template

Demonstrates the most fundamental EDA pattern: an HTTP webhook event fires an
AAP Controller job template.

## Architecture

```
curl POST → EDA Activation (port 5000)
               ↓  condition matches
          run_job_template
               ↓
          AAP Controller: "EDA-Sample-Webhook-Handler"
               ↓
          playbooks/handle_event.yml (on localhost)
```

## Files

| File | Purpose |
|---|---|
| `rulebook.yml` | EDA rulebook with webhook source |
| `playbooks/handle_event.yml` | Playbook triggered by job template |
| `inventory/hosts.yml` | Static localhost inventory |
| `setup_aap.sh` | Creates all required AAP objects |

## Setup (AAP Objects Created by setup_aap.sh)

### AAP Controller
- **Inventory**: `EDA-Sample-Inventory` (localhost)
- **Project**: `EDA-Samples-Project` (this git repo)
- **Job Template**: `EDA-Sample-Webhook-Handler`

### AAP EDA Controller
- **Decision Environment**: `EDA-Community-DE`
- **Project**: `EDA-Samples-EDA-Project`
- **Rulebook Activation**: `sample-webhook-activation`

## Run Setup

```bash
export AAP_BASE="https://aap-aap.apps-crc.testing"
export AAP_TOKEN="<your-gateway-token>"
bash setup_aap.sh
```

## Test the Webhook

```bash
# Get the event stream URL from the activation
ACTIVATION_URL=$(bash get_webhook_url.sh)

# Fire a test event
curl -X POST "$ACTIVATION_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "deploy",
    "target": "webserver",
    "version": "2.1.0"
  }'
```

## What Happens

1. EDA receives the POST
2. Condition `event.payload is defined` matches
3. EDA calls `run_job_template` → AAP Controller launches job
4. Job runs `playbooks/handle_event.yml` with extra vars from event
5. Playbook logs event details and writes an audit file to `/tmp/`

## Expected Job Output

```
TASK [Log received event details]
ok: [localhost] => {
    "msg": [
        "=== EDA Event Received ===",
        "Action:  deploy",
        "Target:  webserver",
        "Version: 2.1.0",
        ...
    ]
}
```
