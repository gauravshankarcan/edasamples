#!/usr/bin/env bash
curl -k -X POST https://eda-limit-jobs-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"compliance_check","target_hosts":"tag_Environment_staging","requestor":"security-team","change_id":"SEC001"}'
