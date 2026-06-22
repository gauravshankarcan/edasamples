#!/usr/bin/env bash
# Test 13 — Regex router: hotfix image tag (non-semver)
#
# What this curl does:
#   POSTs an image push with a hotfix-style tag to eda-regex-demo-activation.
#   The rulebook matches hotfix patterns via is search() and routes to
#   EDA-Regex-Demo with route_type=hotfix and high-priority production target.
#
# Resources to verify it worked:
#   • OpenShift route: eda-regex-demo-activation.apps-crc.testing (HTTP 200)
#   • AAP → Jobs: EDA-Regex-Demo launched (different rule than test 12)
#   • Job stdout: route_type=hotfix, target_environment=production
#   • Job stdout: shows hotfix tag parsing from image field
curl -k -X POST https://eda-regex-demo-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"image":"quay.io/myapp/api:hotfix-critical-login-bug","registry":"quay.io","pipeline":"hotfix","commit_sha":"def5678"}'
