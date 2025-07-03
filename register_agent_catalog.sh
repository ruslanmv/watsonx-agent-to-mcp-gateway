#!/usr/bin/env bash
# register_agent.sh – push hello-world-dev resource + hello-world-agent server
set -euo pipefail

# 1) Activate venv
VENV="./mcpgateway/.venv/bin/activate"
[[ -f $VENV ]] || { echo "❌ No venv at $VENV"; exit 1; }
# shellcheck disable=SC1090
source "$VENV"
echo "✅ Activated virtualenv"

# 2) Credentials
export BASIC_AUTH_USER="${BASIC_AUTH_USER:-admin}"
export BASIC_AUTH_PASSWORD="${BASIC_AUTH_PASSWORD:-changeme}"
export JWT_SECRET_KEY="${JWT_SECRET_KEY:-my-test-key}"

# 3) Mint admin JWT
echo "🔑 Generating ADMIN_TOKEN…"
ADMIN_TOKEN=$(python -m mcpgateway.utils.create_jwt_token \
                --username "$BASIC_AUTH_USER" \
                --secret   "$JWT_SECRET_KEY" \
                --exp      60)
echo "✅ ADMIN_TOKEN generated"

# Helper
jcurl() {
  curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
       -H "Content-Type: application/json" "$@"
}

# 4) Read the agent script
SCRIPT_PATH="agents/hello_world/hello_server_sse.py"
RESOURCE_SLUG="hello-world-dev"
SCRIPT_NAME="$(basename "$SCRIPT_PATH")"
echo "📦 Reading $SCRIPT_PATH…"
CONTENT=$(<"$SCRIPT_PATH")

# 5) Register the resource (inline code)
echo "📦 Registering resource '$RESOURCE_SLUG'…"
RES_PAYLOAD=$(jq -n \
  --arg id      "$RESOURCE_SLUG" \
  --arg name    "$SCRIPT_NAME" \
  --arg type    "inline" \
  --arg uri     "file://$SCRIPT_PATH" \
  --arg code    "$CONTENT" \
  '{id:$id,name:$name,type:$type,uri:$uri,content:$code}')

RES=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$RES_PAYLOAD" \
  http://localhost:4444/resources)
BODY=$(sed '$d' <<<"$RES")
CODE=$(tail -n1  <<<"$RES")

if [[ $CODE =~ ^2 ]]; then
  echo "✅ Resource registered (HTTP $CODE)"
elif [[ $CODE == 409 ]]; then
  echo "⚠️  Resource already exists, skipping"
else
  echo "❌ Resource registration failed (HTTP $CODE):"
  echo "$BODY"
  exit 1
fi

# 6) Register the server pointing to that resource
echo "🚀 Registering hello-world-agent server…"
SV_PAYLOAD=$(jq -n \
  --arg name               "hello-world-agent" \
  --arg desc               "Echo agent over SSE" \
  --argjson associated_tools       '["echo"]' \
  --argjson associated_resources   '["'"$RESOURCE_SLUG"'"]' \
  '{name:$name,
    description:$desc,
    associated_tools:$associated_tools,
    associated_resources:$associated_resources,
    associated_prompts:[] }')

RES=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$SV_PAYLOAD" \
  http://localhost:4444/servers)
BODY=$(sed '$d' <<<"$RES")
CODE=$(tail -n1  <<<"$RES")

if [[ $CODE =~ ^2 ]]; then
  echo "✅ Server registered (HTTP $CODE)"
elif [[ $CODE == 409 ]]; then
  echo "⚠️  Server already exists, skipping"
else
  echo "❌ Server registration failed (HTTP $CODE):"
  echo "$BODY"
  exit 1
fi

# 7) Show servers
echo -e "\n🔍 Servers catalog:"
jcurl http://localhost:4444/servers | jq .
