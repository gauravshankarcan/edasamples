# EDA Samples — Event-Driven Ansible for Ansible Playbook Users

This repository contains a comprehensive set of Event-Driven Ansible (EDA)
samples, best-practice guides, and working AAP integrations covering AWS, Azure,
multi-rule matching, and execution strategy patterns.

## Repository Structure

```
edasamples/
├── rulebooks/                         ← AAP EDA reads rulebooks from here
│   ├── samples-webhook.yml            ← Basic webhook → job template
│   ├── eda-param-deploy.yml           ← Parameterized webhook extra vars
│   ├── eda-limit-jobs.yml             ← Job limit with AWS inventory
│   ├── eda-limit-jobs-azure.yml       ← Job limit with Azure inventory 
│   ├── eda-requestor.yml              ← Response-back-to-requester pattern
│   ├── eda-regex-demo.yml             ← CI/CD image tag router
│   ├── eda-match-single.yml           ← Single-match: exclusive conditions 
│   ├── eda-match-multiple.yml         ← Multi-match: overlapping conditions 
│   ├── eda-execution-sequential.yml   ← Sequential execution strategy 
│   ├── eda-execution-parallel.yml     ← Parallel execution strategy 
│   ├── eda-webhook-bearer.yml         ← Bearer-token authenticated webhook 
│   ├── eda-webhook-hmac.yml           ← HMAC-verified webhook 
│   ├── eda-webhook-mtls.yml           ← mTLS-authenticated webhook 
│   └── eda-event-persistence.yml      ← Event persistence demo (AAP 2.7+) 
│
├── best_practice/                     ← START HERE if new to EDA
│   ├── README.md                      ← Full guide: EDA vs playbook concepts
│   └── samples/                       ← Annotated rulebook examples
│
├── samples/                           ← Webhook → AAP job template (basic)
├── eda_param_samples/                 ← Webhook with parameterized extra vars
├── eda_param_limit_jobs/              ← Webhook + job template limit
│   ├── aws/                           ← AWS EC2 infra (create/inventory/teardown)
│   └── azure/                         ← Azure VM infra (create/inventory/teardown) 
├── eda_match_multiple/                ← match_multiple_rules examples 
├── eda_execution_strategy/            ← execution_strategy examples 
├── eda_requestor/                     ← Callback response back to requester
├── eda_regex_samples/                 ← Regex in EDA conditions
├── eda_webhook_security/              ← Bearer + HMAC webhook auth 
├── eda_event_persistence/             ← Event persistence (AAP 2.7+) 
│
├── decision-environment/              ← Build your own DE
│   ├── CHANGELOG.md                   ← AAP 2.6 → 2.7 DE differences 
│   └── ...
│
├── aap_config/                        ← Full AAP config (Controller + EDA)
│   ├── configure_aap.yml              ← Single playbook to configure everything
│   ├── vars/auth.yml                  ← AWS + Azure credentials 
│   ├── vars/controller_config.yml     ← All inventories, job templates 
│   └── vars/eda_config.yml            ← All activations 
│
├── testcases/                         ← Single curl per test 
│   ├── README.md                      ← Test matrix
│   └── 01_*.sh … 22_*.sh             ← 22 test scripts
│
└── devfile.yaml                       ← OpenShift Dev Spaces workspace 
```

---

## Quick Start

### If you're new to EDA (coming from ansible-playbook)
**Read [`best_practice/README.md`](best_practice/README.md) first.**

### Deploy everything

```bash
source ~/.bashrc_eda_session
ansible-galaxy collection install -r aap_config/requirements.yml
ansible-playbook aap_config/configure_aap.yml \
  -e @aap_config/vault.yml --ask-vault-pass
```

---

## Working Samples

| Sample | Rulebook | Job Template | Activation |
|--------|---------|-------------|-----------|
| Basic webhook | `samples-webhook.yml` | `EDA-Sample-Webhook-Handler` | `sample-webhook-activation` |
| Parameterized | `eda-param-deploy.yml` | `EDA-Param-Deploy-Service` | `eda-param-samples-activation` |
| Host limit (AWS) | `eda-limit-jobs.yml` | `EDA-Limit-OS-Patching` | `eda-limit-jobs-activation` |
| Host limit (Azure) | `eda-limit-jobs-azure.yml` | `EDA-Azure-Limit-OS-Patching` | `eda-azure-limit-jobs-activation` |
| Requestor | `eda-requestor.yml` | `EDA-Requestor-Handler` | `eda-requestor-activation` |
| Regex router | `eda-regex-demo.yml` | `EDA-Regex-Demo` | `eda-regex-demo-activation` |
| Single-match | `eda-match-single.yml` | `EDA-Match-Multiple-Action-A` | `eda-match-single-activation` |
| Multi-match | `eda-match-multiple.yml` | `EDA-Match-Multiple-Action-A/B` | `eda-match-multiple-activation` |
| Sequential strategy | `eda-execution-sequential.yml` | `EDA-Execution-Strategy-Action` | `eda-execution-sequential-activation` |
| Parallel strategy | `eda-execution-parallel.yml` | `EDA-Execution-Strategy-Action` | `eda-execution-parallel-activation` |
| Bearer webhook | `eda-webhook-bearer.yml` | `EDA-Sample-Webhook-Handler` | `eda-webhook-bearer-activation` |
| HMAC webhook | `eda-webhook-hmac.yml` | `EDA-Sample-Webhook-Handler` | `eda-webhook-hmac-activation` |
| mTLS webhook | `eda-webhook-mtls.yml` | `EDA-Sample-Webhook-Handler` | `eda-webhook-mtls-activation` |
| Event persistence | `eda-event-persistence.yml` | `EDA-Event-Persistence-Action` | `eda-event-persistence-activation` |

---

## Event Persistence (AAP 2.7+)

See [`eda_event_persistence/README.md`](eda_event_persistence/README.md).

When `enable_persistence` is on, in-flight events survive activation restarts.
Pair with `restart_on_project_update` to avoid event gaps during project sync.

```bash
# Send event, restart mid-flight, verify job completes
bash testcases/30_event_persistence_restart_verify.sh
```

---

## AAP Environment

- **AAP URL**: https://aap-aap.apps-crc.testing
- **Decision Environment**: `EDA-Community-DE` (includes community.aws, azure.azcollection)
- **DE Image**: `image-registry.openshift-image-registry.svc:5000/aap/eda-community-de:latest`

---

## Phase 1: New Samples

### Azure Cloud (parallel to AWS)

The `eda_param_limit_jobs/azure/` folder mirrors the AWS EC2 pattern for Azure VMs:

```bash
# Create 3 Azure test VMs (web01, web02, db01)
source ~/.bashrc_eda_session
ansible-playbook eda_param_limit_jobs/azure/create_test_vms.yml

# Teardown
ansible-playbook eda_param_limit_jobs/azure/teardown_vms.yml
```

Azure dynamic inventory (`azure/inventory.azure_rm.yml`) creates inventory groups from tags:
- `webservers` (tag `Group=webservers`)
- `env_staging` (tag `Environment=staging`)
- `role_web` (tag `Role=web`)

**Webhook targeting:**
```bash
# Patch by VM name
curl -X POST https://eda-azure-limit-jobs-activation.apps-crc.testing \
  -d '{"action":"patching","target_hosts":"eda-test-web01","change_id":"CHG001"}'

# Patch by tag group
curl -X POST https://eda-azure-limit-jobs-activation.apps-crc.testing \
  -d '{"action":"patching","azure_tag_key":"Group","azure_tag_value":"webservers"}'
```

### DE Changelog (AAP 2.6 → 2.7)

See [`decision-environment/CHANGELOG.md`](decision-environment/CHANGELOG.md) for:
- Python 3.11 → 3.12 migration
- AWS/Azure event sources moving to cloud collections
- New `eda.builtin.*` namespace
- Breaking changes and migration checklist

### Match Multiple Rules

See [`eda_match_multiple/README.md`](eda_match_multiple/README.md) for full explanation.

**Key difference:**
```
Single-match (exclusive conditions):  1 event → 1 rule fires
Multi-match  (overlapping conditions): 1 event → N rules fire
```

```bash
# Single-match: sends ONE event → ONE job template
bash testcases/16_match_single_critical.sh

# Multi-match: sends ONE event → TWO job templates (remediate + notify)
bash testcases/18_match_multiple_critical.sh
```

### Execution Strategy

See [`eda_execution_strategy/README.md`](eda_execution_strategy/README.md).

**Key difference** (activation-level setting, not rulebook):
```
Sequential: Event 2 waits for Event 1's action to complete
Parallel:   Event 2 starts immediately regardless of Event 1
```

```bash
# Sequential: second event queues behind first
bash testcases/19_exec_sequential_event1.sh &
bash testcases/20_exec_sequential_event2.sh

# Parallel: both events process concurrently
bash testcases/21_exec_parallel_event1.sh &
bash testcases/22_exec_parallel_event2.sh
```

---

## Phase 3: Test Cases

The `testcases/` folder contains 22 single-`curl` shell scripts:

```bash
# Run any test:
source ~/.bashrc_eda_session
bash testcases/01_webhook_basic.sh

# See all tests:
cat testcases/README.md
```

---

## Phase 4: OpenShift Dev Spaces

A `devfile.yaml` is included at the repository root. To launch this workspace:

1. In OpenShift Dev Spaces: **Create Workspace** → **From Git Repository**
2. Enter: `https://github.com/gauravshankarcan/edasamples.git`
3. Dev Spaces detects `devfile.yaml` automatically.
4. The workspace includes `ansible-core`, `ansible-builder`, `awx.awx`, and all required collections.

---

## Decision Environment

The DE in this repo includes:
- `ansible-rulebook` (version from base `de-supported-rhel9:latest`)
- `ansible.eda` (built-in and collection sources)
- `community.aws` for legacy AWS sources
- `azure.azcollection` for Azure RM inventory and event sources
- `amazon.aws` for certified AWS event sources (AAP 2.7+)
- `ansible.utils`, `ansible.posix`, `community.crypto`

Build and push to OCP:
```bash
ansible-playbook decision-environment/build_de.yml
```

---

## AWS Test Infrastructure

The `eda_param_limit_jobs` sample creates 3 AWS EC2 instances:
- `eda-test-web01` (webservers group, us-east-1a)
- `eda-test-web02` (webservers group, us-east-1a)
- `eda-test-db01` (databases group, us-east-1a)

Create: `ansible-playbook eda_param_limit_jobs/aws/create_test_instances.yml`
Teardown: `ansible-playbook eda_param_limit_jobs/aws/teardown_instances.yml`

## Azure Test Infrastructure

The Azure counterpart creates 3 Azure VMs:
- `eda-test-web01` (Group=webservers, Environment=staging)
- `eda-test-web02` (Group=webservers, Environment=staging)
- `eda-test-db01` (Group=databases, Environment=staging)

Create: `ansible-playbook eda_param_limit_jobs/azure/create_test_vms.yml`
Teardown: `ansible-playbook eda_param_limit_jobs/azure/teardown_vms.yml`

---

## Key EDA Concepts (TL;DR for Playbook Users)

```
Playbook concept   →  EDA equivalent
────────────────────────────────────────────────────────────────────────
hosts: webservers  →  limit: "webservers" in run_job_template
when: x == "y"     →  condition: event.payload.x == "y"  (Drools DSL)
elif: x == "z"     →  separate rule (no elif in EDA)
register: result   →  action: set_fact: key: "{{ event.payload.val }}"
ansible_facts      →  event.payload.*  (event data, not host facts)
--extra-vars       →  job_args.extra_vars in run_job_template
--limit            →  job_args.limit in run_job_template
serial: 1          →  execution_strategy: sequential (activation setting)
serial: 0 (all)    →  execution_strategy: parallel (activation setting)
EE (for playbooks) →  DE (for rulebooks — different image format)
```
