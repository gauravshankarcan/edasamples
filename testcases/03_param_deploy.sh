#!/usr/bin/env bash
# Test 03 — Parameterized deploy action
#
# What this curl does:
#   POSTs a deploy event to eda-param-samples-activation. The rulebook
#   (rulebooks/eda-param-deploy.yml) matches action=deploy and launches
#   EDA-Param-Deploy-Service with service, version, environment, and replicas
#   passed as job extra vars.
#
# Resources to verify it worked:
#   • OpenShift route: eda-param-samples-activation.apps-crc.testing (HTTP 200)
#   • AAP → Jobs: EDA-Param-Deploy-Service (status successful)
#   • Job stdout: param_action=deploy, service=payment-api, version=3.1.0, env=staging
#   • Job stdout: audit JSON written to /tmp/eda_audit_payment-api_deploy_*.json
curl -kv -X POST https://eda-param-samples-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"deploy","service":"payment-api","version":"3.1.0","environment":"staging","replicas":3,"requestor":"ci-pipeline"}'
