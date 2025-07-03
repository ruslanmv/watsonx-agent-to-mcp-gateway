#!/usr/bin/env bash
set -euo pipefail

# Usage: $0 <ADMIN_TOKEN> "<Your question>"
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <ADMIN_TOKEN> \"<Your question>\"" >&2
  exit 1
fi

ADMIN_TOKEN="$1"
PROMPT="$2"

curl -sS -X POST http://localhost:4444/rpc \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d '{
        "jsonrpc":"2.0",
        "method":"chat",
        "params":{"query":"'"${PROMPT//\"/\\\"}"'"},
        "id":1
      }' \
| jq .
