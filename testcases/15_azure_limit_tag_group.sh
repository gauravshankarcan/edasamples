#!/usr/bin/env bash
curl -k -X POST https://eda-azure-limit-jobs-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"patching","azure_tag_key":"Group","azure_tag_value":"webservers","requestor":"cloud-ops","change_id":"CHG-AZ-002"}'
