# EDA Webhook Security Samples

Demonstrates securing `ansible.eda.webhook` event sources with **Bearer token**
authentication, **HMAC payload verification**, and **mutual TLS (mTLS)**.

| Sample | Rulebook | Activation | Auth mechanism |
|--------|----------|------------|----------------|
| Bearer token | `rulebooks/eda-webhook-bearer.yml` | `eda-webhook-bearer-activation` | `Authorization: Bearer <token>` |
| HMAC signature | `rulebooks/eda-webhook-hmac.yml` | `eda-webhook-hmac-activation` | `x-hub-signature-256: sha256=<hex>` |
| mTLS | `rulebooks/eda-webhook-mtls.yml` | `eda-webhook-mtls-activation` | Client certificate signed by demo CA |

All activations launch the shared `EDA-Sample-Webhook-Handler` job template and
pass `eda_auth_mode` (`bearer`, `hmac`, or `mtls`) as an extra var.

## Demo credentials

These values are embedded in the rulebooks or DE image for lab use only:

| Setting | Value |
|---------|-------|
| Bearer token | `eda-bearer-demo-token` |
| HMAC secret | `eda-hmac-demo-secret` |
| mTLS CA / client cert | `eda_webhook_security/certs/` |
| mTLS server cert in DE | `/etc/eda-webhooks-mtls/` (baked into `EDA-Community-DE`) |

Regenerate demo certificates:

```bash
# Requires openssl (or run via podman alpine as in CI)
bash eda_webhook_security/certs/generate_certs.sh
ansible-playbook decision-environment/build_de.yml
```

## Test cases

```bash
source ~/.bashrc_eda_session
bash testcases/26_webhook_bearer_auth.sh
bash testcases/27_webhook_hmac.sh
bash testcases/28_webhook_mtls.sh
```

## How HMAC signing works

The webhook plugin hashes the **raw request body** with the shared secret:

```bash
BODY='{"action":"deploy","target":"hmac-host","version":"1.0.0"}'
SIG=$(printf '%s' "$BODY" | openssl dgst -sha256 -hmac eda-hmac-demo-secret -hex | sed 's/^.* //')
# Send header: x-hub-signature-256: sha256=${SIG}
```

## How mTLS works

1. The `EDA-Community-DE` image includes demo server and CA certificates.
2. The rulebook enables TLS on port 5000 and requires a client certificate.
3. The OpenShift Route uses **TLS passthrough** so the client handshake reaches the pod.
4. Tests present `client.crt` / `client.key` and trust `ca.crt`.

Requests with a missing/invalid Bearer token, HMAC signature, or client certificate
return **401 Unauthorized** and do not trigger rules.
