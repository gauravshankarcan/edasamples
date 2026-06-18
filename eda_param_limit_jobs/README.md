# EDA Job Template with Limit — Target Specific Hosts

Demonstrates using the `limit` parameter in `run_job_template` to restrict
which hosts in the inventory get actioned, based on EDA event data.

## The Limit Concept

In `ansible-playbook` you use `--limit` to restrict hosts:
```bash
ansible-playbook site.yml --limit "webservers,!db01"
```

In EDA `run_job_template`, the equivalent is:
```yaml
action:
  run_job_template:
    name: "My-Job-Template"
    job_args:
      limit: "{{ event.payload.target_hosts }}"   # ← same as --limit
```

The inventory in AAP contains ALL your managed hosts. The EDA event specifies
**which subset** needs action right now.

## AWS Dynamic Inventory Architecture

```
AWS EC2 Instances (tagged with Group, Environment, Role)
        ↓
Dynamic Inventory (inventory.aws_ec2.yml)
        ↓
AAP Inventory "EDA-AWS-Inventory"
  Groups: webservers, databases, env_staging, tag_Group_webservers...
        ↓
EDA rulebook specifies limit from event payload
        ↓
Job runs only on limited subset
```

## Setup Steps

### 1. Create AWS Test Instances
```bash
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"

ansible-playbook aws/create_test_instances.yml \
  -e aws_region=us-east-1 \
  -e key_pair_name=eda-test-key
```

### 2. Configure AAP
```bash
export AAP_BASE="https://aap-aap.apps-crc.testing"
export AAP_TOKEN="<gateway-token>"
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
bash setup_aap.sh
```

This creates:
- AWS credential in AAP
- Dynamic EC2 inventory "EDA-AWS-Inventory"
- Job template "EDA-Limit-OS-Patching" using EC2 inventory
- EDA activation

## Valid Limit Values

The `target_hosts` field in the webhook payload accepts any of:

| Value | Targets |
|---|---|
| `eda-test-web01` | Single named host |
| `eda-test-web01,eda-test-web02` | Multiple specific hosts |
| `webservers` | All hosts in the `webservers` group |
| `tag_Environment_staging` | All EC2s with tag Environment=staging |
| `tag_Group_webservers` | All EC2s with tag Group=webservers |
| `eda-test-web*` | Wildcard (all hosts matching pattern) |
| `all` | All hosts (use with caution!) |
| `!eda-test-db01` | All hosts EXCEPT db01 |
| `webservers:!eda-test-web02` | webservers group minus web02 |

## Test Examples

```bash
WEBHOOK_URL="http://localhost:5000"

# Patch specific host
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "patching",
    "target_hosts": "eda-test-web01",
    "requestor": "ops-team",
    "change_id": "CHG001"
  }'

# Patch all webservers
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "patching",
    "target_hosts": "webservers",
    "requestor": "ops-team",
    "change_id": "CHG002"
  }'

# Compliance check by AWS tag
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "compliance_check",
    "aws_tag_key": "Environment",
    "aws_tag_value": "staging",
    "requestor": "security-team"
  }'

# Restart nginx on specific hosts
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "restart_service",
    "target_hosts": "eda-test-web01,eda-test-web02",
    "service_name": "nginx",
    "requestor": "ops-team"
  }'
```

## Cleanup

```bash
ansible-playbook aws/teardown_instances.yml -e aws_region=us-east-1
```
