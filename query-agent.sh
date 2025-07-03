#!/usr/bin/env bash
# query-agent.sh
# A simple script to perform a single inference call via the MCP Gateway.
set -euo pipefail

# --- Load environment from .env if present ---
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

# --- Configuration (override via environment or .env) ---
HOST="${MCP_HOST:-localhost}"
PORT="${MCP_PORT:-4444}"

# Agent/tool name registered in the Gateway
AGENT_NAME="${AGENT_NAME:-gpt-agent}"
# The input prompt for your agent
PROMPT="${PROMPT:-Hello, world!}"

# --- Credentials (defaults if not set) ---
BASIC_AUTH_USER="${BASIC_AUTH_USER:-admin}"
JWT_SECRET_KEY="${JWT_SECRET_KEY:-my-test-key}"

# --- Mint a short-lived JWT for authentication ---
ADMIN_TOKEN=$(JWT_SECRET_KEY="$JWT_SECRET_KEY" \
  python3 -m mcpgateway.utils.create_jwt_token \
    --username "$BASIC_AUTH_USER" \
    --secret   "$JWT_SECRET_KEY" \
    --exp      60)

# --- Build JSON-RPC payload ---
data=$(jq -n \
  --arg method "$AGENT_NAME" \
  --arg input  "$PROMPT" \
  '{jsonrpc: "2.0", id: 1, method: $method, params: {input: $input}}')

# --- Send the request and print the response ---
curl -s \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$data" \
  "http://$HOST:$PORT/rpc" | jq .

echo
