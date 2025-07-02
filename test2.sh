#!/usr/bin/env bash
set -euo pipefail

# 1) Activate venv
if [ -f "./mcpgateway/.venv/bin/activate" ]; then
    source ./mcpgateway/.venv/bin/activate
else
    echo "❌ Virtual environment not found at ./mcpgateway/.venv/bin/activate"
    exit 1
fi

# 2) Credentials
export BASIC_AUTH_USER="${BASIC_AUTH_USER:-admin}"
export BASIC_AUTH_PASSWORD="${BASIC_AUTH_PASSWORD:-adminpw}"
export JWT_SECRET_KEY="${JWT_SECRET_KEY:-my-test-key}"

# 3) Mint an Admin JWT
echo "🔑 Minting admin token..."
ADMIN_TOKEN=$(
  python3 -m mcpgateway.utils.create_jwt_token \
    --username "$BASIC_AUTH_USER" \
    --secret   "$JWT_SECRET_KEY" \
    --exp      60
)

# 4) Find the Server ID
echo "🔎 Searching for active 'watsonx-agent'..."
SERVER_ID=$(
  curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
       http://localhost:4444/servers | \
  jq -r '.[] | select(.name=="watsonx-agent" and .isActive==true) | .id'
)

if [[ -z "$SERVER_ID" ]]; then
  echo "❌ Could not find an active server named 'watsonx-agent'."
  echo "   Please ensure the agent is running and registered with the gateway."
  exit 1
fi
echo "✅ Agent found! SERVER_ID=${SERVER_ID}"

# 5) Invoke the agent's 'chat' tool directly
echo "💬 Calling the agent's 'chat' tool..."
RESPONSE=$(
  curl -s -u "$BASIC_AUTH_USER:$BASIC_AUTH_PASSWORD" \
       -H "Authorization: Bearer $ADMIN_TOKEN" \
       -X POST "http://localhost:4444/protocol" \
       -H "Content-Type: application/json" \
       -d '{
             "jsonrpc": "2.0",
             "id":      1,
             "method":  "tool/run",
             "params": {
               "serverId": "'"$SERVER_ID"'",
               "toolName": "chat",
               "inputs": {
                 "query": "Tell me a joke."
               }
             }
           }'
)

# 6) Validate and parse the response
if [[ -z "$RESPONSE" || "${RESPONSE:0:1}" != "{" ]]; then
    echo
    echo "❌ Error: The server returned an unexpected, non-JSON response."
    echo "------------------SERVER RESPONSE-------------------"
    echo "$RESPONSE"
    echo "----------------------------------------------------"
    exit 1
else
    # The response looks like JSON, so now it's safe to parse.
    echo "$RESPONSE" | jq .
fi