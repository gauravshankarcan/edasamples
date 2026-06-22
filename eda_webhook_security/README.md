# EDA Webhook Security Samples

Demonstrates securing `ansible.eda.webhook` event sources with **Bearer token**
authentication and **HMAC payload verification**.

| Sample | Rulebook | Activation | Auth mechanism |
|--------|----------|------------|----------------|
| Bearer token | `rulebooks/eda-webhook-bearer.yml` | `eda-webhook-bearer-activation` | `Authorization: Bearer <token>` |
| HMAC signature | `rulebooks/eda-webhook-hmac.yml` | `eda-webhook-hmac-activation` | `x-hub-signature-256: sha256=<hex>` |

Both activations launch the shared `EDA-Sample-Webhook-Handler` job template and
pass `eda_auth_mode` (`bearer` or `hmac`) as an extra var.

## Demo credentials

These values are embedded in the rulebooks for lab use only:

| Setting | Value |
|---------|-------|
| Bearer token | `eda-bearer-demo-token` |
| HMAC secret | `eda-hmac-demo-secret` |

## Test cases

```bash
source ~/.bashrc_eda_session
bash testcases/26_webhook_bearer_auth.sh
bash testcases/27_webhook_hmac.sh
```

## How HMAC signing works

The webhook plugin hashes the **raw request body** with the shared secret:

```bash
BODY='{"action":"deploy","target":"hmac-host","version":"1.0.0"}'
SIG=$(printf '%s' "$BODY" | openssl dgst -sha256 -hmac eda-hmac-demo-secret -hex | sed 's/^.* //')
# Send header: x-hub-signature-256: sha256=${SIG}
```

Requests with a missing/invalid Bearer token or HMAC signature return **401 Unauthorized**
and do not trigger rules.
