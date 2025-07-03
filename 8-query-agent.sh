#!/usr/bin/env bash
# mcp_tool_tester.sh – choose an agent, choose a tool, send a prompt
set -euo pipefail

GATEWAY="http://localhost:4444"
RPC_URL="${GATEWAY}/rpc"          # ← Gateway’s JSON-RPC endpoint
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
echo "🔑 Minting admin token ..."
ADMIN_TOKEN=$(
  python -m mcpgateway.utils.create_jwt_token \
    --username "$BASIC_AUTH_USER" \
    --secret   "$JWT_SECRET_KEY" \
    --exp      60
)

jget() { curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" "$@"; }

# ───────── 4) Pick an agent ─────────
echo -e "\n📡 Active agents:"
mapfile -t AGENTS < <(jget "${GATEWAY}/servers" |
  jq -r '.[] | select(.isActive) | "\(.name) (\(.id))"')

if ((${#AGENTS[@]} == 0)); then
  echo "❌ No active agents in the Gateway."
  exit 1
fi

select AGENT_LINE in "${AGENTS[@]}"; do
  [[ $AGENT_LINE ]] && break
done
SERVER_ID=$(awk -F'[()]' '{print $2}' <<<"$AGENT_LINE")
SERVER_NAME=$(awk '{print $1}' <<<"$AGENT_LINE")
echo "✅ You picked: $SERVER_NAME  (ID=$SERVER_ID)"

# ───────── 5) Pick a tool ─────────
echo -e "\n🛠  Tools in $SERVER_NAME:"
mapfile -t TOOLS < <(jget "${GATEWAY}/servers/${SERVER_ID}/tools" | jq -r '.[].name')

if ((${#TOOLS[@]} == 0)); then
  echo "❌ No tools exposed by this agent."
  exit 1
fi

select TOOL_LIST_NAME in "${TOOLS[@]}"; do
  [[ $TOOL_LIST_NAME ]] && break
done
echo "✅ You picked: $TOOL_LIST_NAME"


# ───────── 5.5) Set the JSON-RPC Method [FIXED] ─────────
# The JSON-RPC method is the exact name of the tool.
METHOD="$TOOL_LIST_NAME"


# ───────── 6) Prompt text ─────────
read -r -p $'\n💬 Enter your prompt: ' PROMPT
PROMPT=${PROMPT:-What is the capital of Italy?}

# ───────── 7) Build JSON-RPC payload safely ─────────
RPC_BODY=$(jq -n \
  --arg method "$METHOD" \
  --arg q      "$PROMPT" \
  '{jsonrpc:"2.0",id:1,method:$method,params:{query:$q}}')

# ───────── 8) Call the Gateway ─────────
echo -e "\n🚀 Sending request ..."
RESPONSE=$(curl -s \
  -u "${BASIC_AUTH_USER}:${BASIC_AUTH_PASSWORD}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$RPC_BODY" \
  "$RPC_URL")

# ───────── 9) Pretty-print result ─────────
echo -e "\n📨 Full JSON response:"
echo "$RESPONSE" | jq .

echo -e "\n💡 LLM reply text:"
echo "$RESPONSE" | jq -r '.result.reply // .result.content[0].text // "-- no text field --"'