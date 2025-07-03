#!/usr/bin/env bash
set -euo pipefail

# Usage: $0 <SERVER_ID> <QUERY>
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <SERVER_ID> <QUERY>" >&2
  exit 1
fi

SERVER_ID="$1"
QUERY="$2"

# Either read from env or fetch a fresh one
ADMIN_TOKEN="${MCP_ADMIN_TOKEN:-$(./get_token.sh | tail -n1)}"

curl -sS -X POST "http://localhost:4444/rpc" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d '{
        "jsonrpc": "2.0",
        "method": "chat",
        "params": {
          "serverId": "'"${SERVER_ID}"'",
          "query": "'"${QUERY//\"/\\\"}"'"
        },
        "id": 1
      }' \
| jq .
