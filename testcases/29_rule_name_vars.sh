#!/usr/bin/env bash
# Test 29 — Rule name variable expansion via activation extra_var
#
# What this curl does:
#   POSTs a JSON event to eda-rule-name-vars-activation. The rulebook
#   (rulebooks/eda-rule-name-vars.yml) uses Jinja variables in the rule name:
#     Restart service "{{ service_name }}" on host "{{ win_host }}"
#   Variables are supplied via the activation Variables (extra_var) field.
#
# This test validates whether ansible-rulebook expands activation variables in
# rule names at startup (like playbook task names) or fails with undefined.
#
# Resources to verify:
#   • Activation status: running = variables expanded in rule name at startup
#   • Activation History: error mentioning service_name undefined = known limitation
#   • If running + HTTP 200: EDA-Sample-Webhook-Handler job with eda_auth_mode=rule_name_var_test
curl -kv -X POST https://eda-rule-name-vars-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"rule_name_var_test","target":"webserver01","version":"nginx"}'
