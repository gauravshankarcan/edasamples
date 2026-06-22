#!/usr/bin/env bash
# Test 12 — Regex router: stable semver image tag (v1.2.3)
#
# What this curl does:
#   POSTs a CI/CD image push event to eda-regex-demo-activation. The rulebook
#   (rulebooks/eda-regex-demo.yml) uses is match() on the image field to route
#   semver tags (vX.Y.Z) to EDA-Regex-Demo with route_type=stable_release.
#
# Resources to verify it worked:
#   • OpenShift route: eda-regex-demo-activation.apps-crc.testing (HTTP 200)
#   • AAP → Jobs: EDA-Regex-Demo launched
#   • Job stdout: route_type=stable_release, target_environment=production
#   • Job stdout: regex_replace extracts version 1.2.3 from image tag
curl -k -X POST https://eda-regex-demo-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"image":"quay.io/myapp/api:v1.2.3","registry":"quay.io","pipeline":"ci-cd","commit_sha":"abc1234"}'
