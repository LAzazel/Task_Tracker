#!/usr/bin/env bash
set -euo pipefail

base_url="http://localhost"

curl -fsS "${base_url}/" > /dev/null
curl -fsS -H "Accept: application/json" "${base_url}/tasks" > /dev/null

status=$(curl -s -o /dev/null -w "%{http_code}" "${base_url}/health/alive")
if [[ "$status" != "404" ]]; then
  echo "Expected /health/alive to be blocked by nginx" >&2
  exit 1
fi

echo "Verification OK"

