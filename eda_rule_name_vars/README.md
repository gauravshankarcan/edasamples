# Rule Name Variable Expansion Test

This sample reproduces the question of whether **activation Variables** (`extra_var`)
expand Jinja templates in **rule names** the same way playbook task names do.

## Rulebook

`rulebooks/eda-rule-name-vars.yml` defines:

```yaml
- name: 'Restart service "{{ service_name }}" on host "{{ win_host }}"'
```

Activation `eda-rule-name-vars-activation` passes:

```yaml
extra_var:
  service_name: nginx
  win_host: webserver01
```

## Expected behavior (playbook analogy)

In Ansible playbooks, `name: "Restart {{ service }}"` expands at runtime when
`service` is defined — this is valid and common.

## Observed behavior (ansible-rulebook)

| How variables are supplied | Rule name expansion |
|---------------------------|---------------------|
| `ansible-rulebook --vars vars.yml` | Works — name becomes `Restart service "nginx" on host "webserver01"` |
| No `--vars` at startup | Fails — `'service_name' is undefined` |
| AAP activation `extra_var` | **Test with testcase 29** — if activation fails to start, variables are not available early enough for rule names |

Rule **actions** (`extra_vars`, `debug.msg`) can reference the same variables
even when rule names fail, because those are evaluated per-event at runtime.

## Test

```bash
source ~/.bashrc_eda_session
bash testcases/29_rule_name_vars.sh
```

Verify:
- Activation status in AAP → EDA → Activations
- Activation History logs for startup errors mentioning `service_name` undefined
- If running: job `EDA-Sample-Webhook-Handler` with `eda_auth_mode=rule_name_var_test`
