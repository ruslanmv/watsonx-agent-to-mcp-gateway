#!/usr/bin/env bash
# 11-query-watsonx-agent.sh – An interactive script to query the watsonx-agent.
set -euo pipefail

# --- Configuration ---
GATEWAY="http://localhost:4444"
RPC_URL="${GATEWAY}/rpc"
VENV_PATH="./mcpgateway/.venv"

# The agent's tool to call directly.
# For federated agents, the method is the full tool name.
METHOD="watsonx-agent-chat"

# --- 1) Activate venv ---
if [[ -f "${VENV_PATH}/bin/activate" ]]; then
  # shellcheck disable=SC1090
  source "${VENV_PATH}/bin/activate"
else
  echo "❌ Virtual environment not found at ${VENV_PATH}"
  exit 1
fi

# --- 2) Credentials ---
export BASIC_AUTH_USER="${BASIC_AUTH_USER:-admin}"
export BASIC_AUTH_PASSWORD="${BASIC_AUTH_PASSWORD:-adminpw}"
export JWT_SECRET_KEY="${JWT_SECRET_KEY:-my-test-key}"

# --- 3) Mint JWT ---
echo "🔑 Minting admin token ..."
ADMIN_TOKEN=$(
  python -m mcpgateway.utils.create_jwt_token \
    --username "$BASIC_AUTH_USER" \
    --secret   "$JWT_SECRET_KEY" \
    --exp      60
)

# --- 4) Get Prompt from User ---
echo -e "\n🎯 Calling tool: $METHOD"
# Prompt the user to enter their query.
read -r -p "💬 Enter your prompt: " PROMPT
# Use a default prompt if the user enters nothing.
PROMPT=${PROMPT:-What is the capital of Italy?}

# --- 5) Build JSON-RPC payload safely ---
RPC_BODY=$(jq -n \
  --arg method "$METHOD" \
  --arg q      "$PROMPT" \
  '{jsonrpc:"2.0",id:1,method:$method,params:{query:$q}}')

# --- 6) Call the Gateway ---
echo -e "\n🚀 Sending request ..."
RESPONSE=$(curl -s \
  -u "${BASIC_AUTH_USER}:${BASIC_AUTH_PASSWORD}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$RPC_BODY" \
  "$RPC_URL")

# --- 7) Pretty-print result ---
echo -e "\n📨 Full JSON response:"
echo "$RESPONSE" | jq .

echo -e "\n💡 LLM reply text:"
# Extracts the text from the response, handling different possible structures.
echo "$RESPONSE" | jq -r '.result.reply // .result.content[0].text // "-- no text field --"'