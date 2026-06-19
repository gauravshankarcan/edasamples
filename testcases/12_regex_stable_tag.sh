#!/usr/bin/env bash
curl -k -X POST https://eda-regex-demo-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"image":"quay.io/myapp/api:v1.2.3","registry":"quay.io","pipeline":"ci-cd","commit_sha":"abc1234"}'
