# EDA Samples — Event-Driven Ansible for Ansible Playbook Users

This repository contains a comprehensive set of Event-Driven Ansible (EDA)
samples, best-practice guides, and working AAP integrations.

## Repository Structure

```
edasamples/
├── rulebooks/                    ← AAP EDA reads rulebooks from here
│   ├── samples-webhook.yml       ← Basic webhook → job template
│   ├── eda-param-deploy.yml      ← Parameterized webhook extra vars
│   ├── eda-limit-jobs.yml        ← Job template with host limit
│   └── eda-requestor.yml         ← Response-back-to-requester pattern
│
├── best_practice/                ← START HERE if new to EDA
│   ├── README.md                 ← Full guide: EDA vs playbook concepts
│   └── samples/                  ← Annotated rulebook examples
│
├── samples/                      ← Webhook → AAP job template (basic)
├── decision-environment/         ← Build your own DE with community.aws
├── eda_param_samples/            ← Webhook with parameterized extra vars
├── eda_param_limit_jobs/         ← Webhook + job template limit + AWS EC2
└── eda_requestor/                ← Callback response back to requester
```

## Quick Start

### If you're new to EDA (coming from ansible-playbook)
**Read [`best_practice/README.md`](best_practice/README.md) first.**

It explains:
- How EDA components map to playbook components
- The critical difference between `event.*`, `facts.*`, and `ansible_facts`
- Condition syntax differences from `when:` in playbooks
- Decision Environments vs Execution Environments

### Working Samples in AAP

| Sample | Rulebook | Job Template | Activation |
|---|---|---|---|
| Basic webhook | `samples-webhook.yml` | `EDA-Sample-Webhook-Handler` | `sample-webhook-activation` |
| Parameterized | `eda-param-deploy.yml` | `EDA-Param-Deploy-Service` | `eda-param-samples-activation` |
| Host limit | `eda-limit-jobs.yml` | `EDA-Limit-OS-Patching` | `eda-limit-jobs-activation` |
| Requestor | `eda-requestor.yml` | `EDA-Requestor-Handler` | `eda-requestor-activation` |

### AAP Environment
- **AAP URL**: https://aap-aap.apps-crc.testing
- **Decision Environment**: `EDA-Community-DE` (includes community.aws 11.0.0)
- **DE Image**: `image-registry.openshift-image-registry.svc:5000/aap/eda-community-de:latest`
- **OCP ImageStream**: `aap/eda-community-de:latest`

## Decision Environment

The DE in this repo includes:
- `ansible-rulebook` 1.1.7
- `ansible.eda` 2.10.0
- `community.aws` 11.0.0
- `amazon.aws` 11.3.0
- `boto3` 1.34.x

Build and push to OCP:
```bash
ansible-playbook decision-environment/build_de.yml
```

## AWS Test Infrastructure

The `eda_param_limit_jobs` sample creates 3 AWS EC2 instances:
- `eda-test-web01` (webservers group, us-east-1a)
- `eda-test-web02` (webservers group, us-east-1a)
- `eda-test-db01` (databases group, us-east-1a)

Create: `ansible-playbook eda_param_limit_jobs/aws/create_test_instances.yml`
Teardown: `ansible-playbook eda_param_limit_jobs/aws/teardown_instances.yml`

## Key EDA Concepts (TL;DR for Playbook Users)

```
Playbook concept  →  EDA equivalent
─────────────────────────────────────────────────────────
hosts: webservers  →  limit: "webservers" in run_job_template
when: x == "y"     →  condition: event.payload.x == "y"  (Drools DSL, not Jinja2)
register: result   →  action: set_fact: key: "{{ event.payload.val }}"
ansible_facts      →  event.payload.*  (completely different — event data, not host facts)
--extra-vars       →  job_args.extra_vars in run_job_template
--limit            →  job_args.limit in run_job_template
EE (for playbooks) →  DE (for rulebooks — different image)
```
