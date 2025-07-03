#!/usr/bin/env bash
# mcp_tool_tester.sh
set -euo pipefail

GATEWAY="http://localhost:4444"
VENV_PATH="./mcpgateway/.venv"

# ───────── 1) Activate venv ─────────
if [[ -f "${VENV_PATH}/bin/activate" ]]; then
  # shellcheck disable=SC1090
  source "${VENV_PATH}/bin/activate"
else
  echo "❌ Virtual environment not found at ${VENV_PATH}"
  exit 1
fi

# ───────── 2) Credentials ─────────
export BASIC_AUTH_USER="${BASIC_AUTH_USER:-admin}"
export BASIC_AUTH_PASSWORD="${BASIC_AUTH_PASSWORD:-adminpw}"
export JWT_SECRET_KEY="${JWT_SECRET_KEY:-my-test-key}"

# ───────── 3) Mint JWT ─────────
echo "🔑 Minting admin token..."
ADMIN_TOKEN=$(
  python -m mcpgateway.utils.create_jwt_token \
    --username "$BASIC_AUTH_USER" \
    --secret   "$JWT_SECRET_KEY" \
    --exp      60
)

# Convenience curl function
jcurl() {
  curl -s \
       -H "Authorization: Bearer ${ADMIN_TOKEN}" \
       -H "Content-Type: application/json" \
       "$@"
}

# ───────── 4) List servers and pick one ─────────
echo -e "\n📡 Fetching active agents…"
servers_json=$(jcurl "${GATEWAY}/servers")

server_count=$(echo "$servers_json" | jq '[ .[] | select(.isActive==true) ] | length')
if [[ $server_count -eq 0 ]]; then
  echo "❌ No active agents registered in the Gateway."
  exit 1
fi

echo "Available agents:"
mapfile -t server_menu < <(
  echo "$servers_json" | jq -r '
    [ .[] | select(.isActive==true) | "\(.name) (\(.id))" ] |
    .[]'
)
select server_line in "${server_menu[@]}"; do
  if [[ -n "$server_line" ]]; then
    SERVER_ID=$(awk -F'[()]' '{print $2}' <<< "$server_line")
    SERVER_NAME=$(awk '{print $1}' <<< "$server_line")
    break
  fi
done
echo "✅ Selected agent: $SERVER_NAME  (ID=$SERVER_ID)"

# ───────── 5) List tools for that agent ─────────
echo -e "\n🛠  Fetching tools for $SERVER_NAME…"
tools_json=$(jcurl "${GATEWAY}/tools" | jq --arg sid "$SERVER_ID" '[ .[] | select(.serverId==$sid) ]')
tool_count=$(echo "$tools_json" | jq 'length')
if [[ $tool_count -eq 0 ]]; then
  echo "❌ No tools found for this agent."
  exit 1
fi

echo "Tools:"
mapfile -t tool_menu < <(
  echo "$tools_json" | jq -r '.[] | "\(.name)"'
)
select TOOL_NAME in "${tool_menu[@]}"; do
  [[ -n "$TOOL_NAME" ]] && break
done
echo "✅ Selected tool: $TOOL_NAME"

# ───────── 6) Prompt for inputs JSON ─────────
echo
read -r -p "📝 Enter JSON inputs (or leave empty for {}): " INPUTS
INPUTS=${INPUTS:-{}}

# Quick validation
if ! echo "$INPUTS" | jq empty 2>/dev/null; then
  echo "❌ Invalid JSON. Exiting."
  exit 1
fi

# ───────── 7) Invoke tool ─────────
echo -e "\n🚀 Running tool ..."
response=$(
  curl -s -u "${BASIC_AUTH_USER}:${BASIC_AUTH_PASSWORD}" \
       -H "Authorization: Bearer ${ADMIN_TOKEN}" \
       -H "Content-Type: application/json" \
       -X POST "${GATEWAY}/protocol" \
       -d '{
             "jsonrpc": "2.0",
             "id":      1,
             "method":  "tool/run",
             "params": {
               "serverId": "'"${SERVER_ID}"'",
               "toolName": "'"${TOOL_NAME}"'",
               "inputs": '"${INPUTS}"'
             }
           }'
)

# ───────── 8) Show result ─────────
echo -e "\n📨 Response:"
if [[ -z "$response" || "${response:0:1}" != "{" ]]; then
  echo "$response"
else
  echo "$response" | jq .
fi
