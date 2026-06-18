# EDA Requestor Pattern — Response Back to Caller

EDA webhooks are fire-and-forget: the caller sends a POST and gets a `200 OK`
acknowledging the event was received — but not the **result** of the automation.

This sample implements the **callback/requester pattern** so that the EDA
automation result is returned to the original caller.

## How It Works

```
1. Requester sends POST with callback_url in payload
   ┌─────────────┐     POST /webhook              ┌─────────────┐
   │  Requester  │ ─────────────────────────────→ │ EDA Webhook │
   │  (caller)   │ ← 200 OK (event received)      │  (port 5000)│
   └─────────────┘                                 └──────┬──────┘
                                                          │ condition matches
                                                          ↓
                                                   run_job_template
                                                          │
                                                          ↓
                                                   ┌─────────────┐
                                                   │AAP Job runs │
                                                   │  the work   │
                                                   └──────┬──────┘
                                                          │ POST to callback_url
                                                          ↓
   ┌─────────────┐     POST /callback             ┌─────────────┐
   │  Requester  │ ← ─────────────────────────── │  Playbook   │
   │  (receives  │   {status, result, request_id} │  (URI task) │
   │   result)   │                                └─────────────┘
   └─────────────┘
```

## Payload Schema

### Request (POST to EDA webhook)
```json
{
  "request_id":    "unique-correlation-uuid",
  "callback_url":  "https://your-server/receive-result",
  "action":        "provision | check | remediate",
  "resource":      "name-of-resource",
  "parameters":    { "key": "value" },
  "requestor":     "user@example.com",
  "timeout_secs":  300
}
```

### Callback Response (POST from playbook to callback_url)
```json
{
  "request_id":    "unique-correlation-uuid",
  "status":        "success | failure",
  "result":        { "action-specific": "data" },
  "message":       "Human readable summary",
  "action":        "check",
  "resource":      "name-of-resource",
  "requestor":     "user@example.com",
  "started_at":    "2026-01-01T12:00:00Z",
  "completed_at":  "2026-01-01T12:00:45Z"
}
```

## Files

| File | Purpose |
|---|---|
| `rulebook.yml` | EDA rulebook — receives events, fires job template |
| `playbooks/handle_with_callback.yml` | Does the work and POSTs result back |
| `tests/mock_callback_server.py` | Python HTTP server to receive callbacks (testing) |
| `tests/test_request.yml` | End-to-end test playbook |
| `setup_aap.yml` | Create all AAP objects |

## Testing End-to-End

### Step 1: Set up AAP objects
```bash
export AAP_BASE="https://aap-aap.apps-crc.testing"
export AAP_TOKEN="<gateway-token>"
ansible-playbook eda_requestor/setup_aap.yml
```

### Step 2: Start the mock callback server
```bash
python3 eda_requestor/tests/mock_callback_server.py --port 8888
```

### Step 3: Send a test request to EDA
```bash
MY_IP=$(hostname -I | cut -d' ' -f1)
ansible-playbook eda_requestor/tests/test_request.yml \
  -e "eda_url=https://<activation-route>" \
  -e "callback_url=http://${MY_IP}:8888/callback"
```

### Step 4: Watch the mock server terminal
Within ~30-60 seconds (job queue + playbook run time), the mock server will print:
```
============================================================
  EDA CALLBACK RECEIVED at 2026-01-01T12:00:45Z
  Path: /callback
  Headers:
    X-EDA-Request-ID: test-12345
    X-EDA-Callback: true
  Body:
    {
        "request_id": "test-12345",
        "status": "success",
        "result": { ... },
        "message": "Resource prod-web-server-01 health check passed",
        ...
    }
============================================================
```

## Design Considerations

### Correlation IDs
Always include a `request_id` in every event. This allows:
- Tracing an event through EDA → AAP → playbook → callback
- De-duplication if the same event is retried
- Audit trail in AAP job history

### Timeouts
The `timeout_secs` field is informational — the playbook uses it to decide
whether to skip the callback if the caller has likely already timed out.
Implement check: `if elapsed_time > timeout_secs: skip_callback`.

### Callback Security
In production, secure the callback endpoint:
- Use HTTPS
- Verify the `X-EDA-Request-ID` header matches what was sent
- Use a shared secret or signed JWT in the callback
- Whitelist the AAP instance IP(s)

### Idempotency
If the same `request_id` arrives twice (duplicate event), the playbook should:
- Check if already processed (e.g., check a database or job history)
- Return the cached result instead of running again
