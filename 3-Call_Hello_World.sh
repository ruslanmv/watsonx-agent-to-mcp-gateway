#!/usr/bin/env bash
# call_echo.sh – invoke any federated MCP tool via Gateway /rpc
set -euo pipefail

# ─── Configuration ──────────────────────────────────────────────────────────
GATEWAY_URL="${GATEWAY_URL:-http://localhost:4444}"
RPC_URL="${GATEWAY_URL}/rpc"

# First argument: full tool name as shown in Admin UI (e.g. "hello-world-dev-echo")
TOOL_NAME="${1:-hello-world-dev-echo}"
# Second argument: the text to echo
PROMPT="${2:-Hello, world!}"

# Basic Auth (if Gateway still requires it on /rpc)
BASIC_AUTH_USER="${BASIC_AUTH_USER:-admin}"
BASIC_AUTH_PASS="${BASIC_AUTH_PASS:-changeme}"

# JWT settings (must match Gateway's JWT_SECRET_KEY)
JWT_SECRET_KEY="${JWT_SECRET_KEY:-my-test-key}"

# ─── Mint an admin token (valid 60s) ────────────────────────────────────────
ADMIN_TOKEN=$(python3 -m mcpgateway.utils.create_jwt_token \
  --username "$BASIC_AUTH_USER" \
  --secret   "$JWT_SECRET_KEY" \
  --exp      60)

# ─── Build JSON-RPC payload via jq (ensures proper escaping) ───────────────
JSON_PAYLOAD=$(jq -n \
  --arg method "$TOOL_NAME" \
  --arg txt    "$PROMPT" \
  '{jsonrpc:"2.0",id:1,method:$method,params:{text:$txt}}')

# ─── Invoke the tool and show response ─────────────────────────────────────
echo
echo "🚀 Calling tool: $TOOL_NAME"
echo "   Prompt: \"$PROMPT\""
echo

curl -s -u "${BASIC_AUTH_USER}:${BASIC_AUTH_PASS}" \
     -H "Authorization: Bearer ${ADMIN_TOKEN}" \
     -H "Content-Type: application/json" \
     -d "$JSON_PAYLOAD" \
     "$RPC_URL" \
  | jq .

echo
