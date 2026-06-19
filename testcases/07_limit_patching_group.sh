#!/usr/bin/env bash
curl -k -X POST https://eda-limit-jobs-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"patching","target_hosts":"webservers","requestor":"ops-team","change_id":"CHG002"}'
