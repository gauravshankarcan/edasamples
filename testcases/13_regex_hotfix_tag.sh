#!/usr/bin/env bash
curl -X POST https://eda-regex-demo-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"image":"quay.io/myapp/api:hotfix-critical-login-bug","registry":"quay.io","pipeline":"hotfix","commit_sha":"def5678"}'
