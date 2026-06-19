#!/usr/bin/env bash
curl -k -X POST https://eda-param-samples-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"scale","service":"payment-api","replicas":5,"environment":"production","requestor":"autoscaler"}'
