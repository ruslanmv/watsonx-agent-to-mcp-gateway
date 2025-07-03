#!/usr/bin/env bash
# register_agent.sh – push hello_world agent to MCP Gateway
set -euo pipefail

###############################################################################
# 1. Activate venv
###############################################################################
VENV="./mcpgateway/.venv/bin/activate"
[[ -f $VENV ]] || { echo "❌ venv missing at $VENV"; exit 1; }
# shellcheck disable=SC1090
source "$VENV"
echo "✅ Activated virtualenv"

###############################################################################
# 2. Credentials
###############################################################################
export BASIC_AUTH_USER="${BASIC_AUTH_USER:-admin}"
export BASIC_AUTH_PASSWORD="${BASIC_AUTH_PASSWORD:-changeme}"
export JWT_SECRET_KEY="${JWT_SECRET_KEY:-my-test-key}"

###############################################################################
# 3. Admin JWT (60 s)
###############################################################################
echo "🔑 Generating ADMIN_TOKEN…"
ADMIN_TOKEN=$(python -m mcpgateway.utils.create_jwt_token \
                --username "$BASIC_AUTH_USER" \
                --secret   "$JWT_SECRET_KEY"  \
                --exp      60)
echo "✅ ADMIN_TOKEN generated"

###############################################################################
# 4. Read agent script
###############################################################################
SCRIPT_PATH="agents/hello_world/hello_server_sse.py"
RESOURCE_SLUG="hello-world-dev"
SCRIPT_NAME="$(basename "$SCRIPT_PATH")"
echo "📦 Reading $SCRIPT_PATH …"
CONTENT=$(<"$SCRIPT_PATH")

###############################################################################
# 5. Create / update resource
###############################################################################
echo "📦 Registering resource '$RESOURCE_SLUG' …"
RES_PAYLOAD=$(jq -n \
  --arg id   "$RESOURCE_SLUG" \
  --arg name "$SCRIPT_NAME"   \
  --arg type "inline"         \
  --arg uri  "file://$SCRIPT_PATH" \
  --arg code "$CONTENT" \
  '{id:$id,name:$name,type:$type,uri:$uri,content:$code}')

RES_BODY=$(curl -s -w '\n%{http_code}' \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$RES_PAYLOAD" \
  http://localhost:4444/resources)

RES_STATUS=$(tail -n1 <<<"$RES_BODY")
RES_JSON=$(sed '$d'   <<<"$RES_BODY")

if [[ $RES_STATUS =~ ^2 ]]; then
  echo "✅ Resource registered (HTTP $RES_STATUS)"
elif [[ $RES_STATUS == 409 ]]; then
  echo "⚠️  Resource already exists – fetching numeric id"
  RES_JSON=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
                   "http://localhost:4444/resources/$RESOURCE_SLUG")
else
  echo "❌ Resource registration failed:"; echo "$RES_JSON"; exit 1
fi

RESOURCE_NUM_ID=$(jq '.id' <<<"$RES_JSON")
echo "ℹ️  Numeric resource id = $RESOURCE_NUM_ID"

###############################################################################
# 6. Register server
###############################################################################
echo "🚀 Registering hello-world-agent server …"
SV_PAYLOAD=$(jq -n \
  --arg name "hello-world-agent" \
  --arg desc "Demo agent that echoes input (SSE transport)" \
  --argjson tools      '["echo"]' \
  --argjson resources  "[$RESOURCE_NUM_ID]" \
  '{name:$name,
    description:$desc,
    associated_tools:$tools,
    associated_resources:$resources}')

SV_BODY=$(curl -s -w '\n%{http_code}' \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$SV_PAYLOAD" \
  http://localhost:4444/servers)

SV_STATUS=$(tail -n1 <<<"$SV_BODY")

if [[ $SV_STATUS =~ ^2 ]]; then
  echo "✅ Server registered (HTTP $SV_STATUS)"
elif [[ $SV_STATUS == 409 ]]; then
  echo "⚠️  Server already exists – skipping"
else
  echo "❌ Server registration failed:"; sed '$d' <<<"$SV_BODY"; exit 1
fi

###############################################################################
# 7. Show all servers
###############################################################################
echo -e "\n🔍 Current servers:"
curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" \
     http://localhost:4444/servers | jq .
