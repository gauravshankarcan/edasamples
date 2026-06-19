#!/usr/bin/env bash
curl -X POST https://eda-limit-jobs-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"patching","aws_tag_key":"Group","aws_tag_value":"webservers","requestor":"ops-team","change_id":"CHG003"}'
