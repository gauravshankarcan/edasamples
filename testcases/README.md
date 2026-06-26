# Test Cases

Each script contains a **single verbose `curl` command** (`-v`) that triggers one EDA activation.
Run any script directly after sourcing your environment:

```bash
source ~/.bashrc_eda_session
bash testcases/01_webhook_basic.sh
```

## Prerequisites

All activations must be running with debug log level. Deploy everything with:

```bash
source ~/.bashrc_eda_session
ansible-playbook setup_all_aap.yml
```

## Test Matrix

| Script | Activation | What it tests |
|--------|-----------|--------------|
| `01_webhook_basic.sh` | sample-webhook-activation | Basic webhook → job template |
| `02_webhook_hello.sh` | sample-webhook-activation | Alternate webhook payload |
| `03_param_deploy.sh` | eda-param-samples-activation | Deploy action with service/version/env |
| `04_param_rollback.sh` | eda-param-samples-activation | Rollback action |
| `05_param_scale.sh` | eda-param-samples-activation | Scale action with replicas |
| `06_limit_patching_single_host.sh` | eda-limit-jobs-activation | Patch single host by name |
| `07_limit_patching_group.sh` | eda-limit-jobs-activation | Patch all hosts in a group |
| `08_limit_compliance_check.sh` | eda-limit-jobs-activation | Compliance check by tag |
| `09_limit_restart_service.sh` | eda-limit-jobs-activation | Restart nginx on multiple hosts |
| `10_limit_aws_tag.sh` | eda-limit-jobs-activation | Target by AWS tag key/value |
| `11_requestor_callback.sh` | eda-requestor-activation | Request with callback URL |
| `12_regex_stable_tag.sh` | eda-regex-demo-activation | Semver image tag (v1.2.3) |
| `13_regex_hotfix_tag.sh` | eda-regex-demo-activation | Hotfix image tag (routes differently) |
| `14_azure_limit_single_vm.sh` | eda-azure-limit-jobs-activation | Patch single Azure VM by name |
| `15_azure_limit_tag_group.sh` | eda-azure-limit-jobs-activation | Target Azure VMs by tag group |
| `16_match_single_critical.sh` | eda-match-single-activation | Critical alert → ONE rule fires |
| `17_match_single_high.sh` | eda-match-single-activation | High alert → ONE rule fires (different rule) |
| `18_match_multiple_critical.sh` | eda-match-multiple-activation | Critical alert → TWO rules fire |
| `19_exec_sequential_event1.sh` | eda-execution-sequential-activation | Sequential: first event (10s job) |
| `20_exec_sequential_event2.sh` | eda-execution-sequential-activation | Sequential: second event (waits for first) |
| `21_exec_parallel_event1.sh` | eda-execution-parallel-activation | Parallel: first event (10s job) |
| `22_exec_parallel_event2.sh` | eda-execution-parallel-activation | Parallel: second event (runs concurrently) |
| `23_vault_report.sh` | eda-vault-demo-activation | Vault report — secrets accessible |
| `24_vault_verify.sh` | eda-vault-demo-activation | Vault verify — password complexity check |
| `25_vault_rotate.sh` | eda-vault-demo-activation | Vault rotate — simulated rotation workflow |
| `26_webhook_bearer_auth.sh` | eda-webhook-bearer-activation | Bearer token authenticated webhook |
| `27_webhook_hmac.sh` | eda-webhook-hmac-activation | HMAC-SHA256 signed webhook payload |
| `28_webhook_mtls.sh` | eda-webhook-mtls-activation | mTLS client certificate authenticated webhook |
| `29_event_persistence_send.sh` | eda-event-persistence-activation | 1 of 3 hits — HTTP 200, no job yet |
| `30_event_persistence_restart_verify.sh` | eda-event-persistence-activation | 2 hits + restart + hit 3 — job if persistence on |

## Outbound callback (test 11)

Test `11_requestor_callback.sh` POSTs results to `https://eok4z67q40cbzt2.m.pipedream.net`.
Verify the callback arrived in your Pipedream workflow event history after the
EDA-Requestor-Handler job completes successfully.

## AWS limit tests (06–10) prerequisites

Tests 06–10 require AWS EC2 test instances and AAP configuration:

- Create instances: `ansible-playbook eda_param_limit_jobs/aws/create_test_instances.yml`
- Inventory: `EDA-AWS-Dynamic-Inventory` with `ansible_host` compose and `EDA-EC2-SSH-Credential`
- SSH key: `/tmp/eda-test-key.pem` (created by the AWS setup playbook)

## Azure limit tests (14–15) prerequisites

Tests 14–15 require Azure VMs tagged `Owner=eda-samples`:

- Create VMs: `ansible-playbook eda_param_limit_jobs/azure/create_test_vms.yml`
- Inventory: `EDA-Azure-Inventory` synced with `EDA-Azure-Credential`

## Running Sequential vs Parallel Demo

To see the timing difference clearly:

```bash
# Sequential — send both events quickly, observe second waits
bash testcases/19_exec_sequential_event1.sh &
sleep 1
bash testcases/20_exec_sequential_event2.sh
# In AAP Jobs: event2 starts only after event1 finishes (~10s later)

# Parallel — send both events quickly, observe both run simultaneously
bash testcases/21_exec_parallel_event1.sh &
sleep 1
bash testcases/22_exec_parallel_event2.sh
# In AAP Jobs: both jobs run at the same time
```

## Running Multi-Match Demo

```bash
# Single match — check AAP Jobs: only ONE job launched
bash testcases/16_match_single_critical.sh
# Expected: 1 job (Action-A with rule "Handle-Critical-Severity")

# Multiple match — check AAP Jobs: TWO jobs launched for same event
bash testcases/18_match_multiple_critical.sh
# Expected: 2 jobs (Action-A for remediation + Action-B for notification)
```
