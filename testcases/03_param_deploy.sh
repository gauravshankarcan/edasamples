#!/usr/bin/env bash
curl -k -X POST https://eda-param-samples-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"deploy","service":"payment-api","version":"3.1.0","environment":"staging","replicas":3,"requestor":"ci-pipeline"}'
