#!/usr/bin/env bash
# Test 10 — AWS host limit: target by EC2 tag key/value (Group=webservers)
#
# What this curl does:
#   POSTs a patching event with aws_tag_key=Group and aws_tag_value=webservers.
#   The rulebook builds limit=tag_Group_webservers. The AWS inventory must expose
#   a tag_Group_webservers group (keyed_groups prefix tag_Group_ on tags.Group).
#
# Prerequisites: same as test 06 (AWS EC2 test infra + SSH credential + inventory sync)
#
# Resources to verify it worked:
#   • OpenShift route: eda-limit-jobs-activation.apps-crc.testing (HTTP 200)
#   • AAP → Inventories → Groups: tag_Group_webservers (web01 + web02)
#   • AAP → Jobs: EDA-Limit-OS-Patching, limit=tag_Group_webservers, successful
curl -kv -X POST https://eda-limit-jobs-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"action":"patching","aws_tag_key":"Group","aws_tag_value":"webservers","requestor":"ops-team","change_id":"CHG003"}'
