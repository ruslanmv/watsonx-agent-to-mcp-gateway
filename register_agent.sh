#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# 1) Activate Python virtualenv
# -----------------------------------------------------------------------------
VENV="./mcpgateway/.venv/bin/activate"
if [ ! -f "$VENV" ]; then
  echo "❌ Virtualenv not found at $VENV; please run setup first." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$VENV"
echo "✅ Activated virtualenv"

# -----------------------------------------------------------------------------
# 2) Load or default your admin credentials
# -----------------------------------------------------------------------------
export BASIC_AUTH_USER="${BASIC_AUTH_USER:-admin}"
export BASIC_AUTH_PASSWORD="${BASIC_AUTH_PASSWORD:-changeme}"
export JWT_SECRET_KEY="${JWT_SECRET_KEY:-my-test-key}"

# -----------------------------------------------------------------------------
# 3) Generate a short-lived admin JWT (valid 60s)
# -----------------------------------------------------------------------------
echo "🔑 Generating ADMIN_TOKEN…"
ADMIN_TOKEN=$(
  JWT_SECRET_KEY="$JWT_SECRET_KEY" \
    python3 -m mcpgateway.utils.create_jwt_token \
      --username "$BASIC_AUTH_USER" \
      --secret   "$JWT_SECRET_KEY" \
      --exp      60
)
export ADMIN_TOKEN
echo "✅ ADMIN_TOKEN generated"

# -----------------------------------------------------------------------------
# 4) Prepare the resource payload
# -----------------------------------------------------------------------------
RESOURCE_ID="hello-world-agent-script"
SCRIPT_PATH="agents/hello_world/hello_server.py"
SCRIPT_NAME="$(basename "$SCRIPT_PATH")"
echo "📦 Reading script contents from $SCRIPT_PATH…"
# Use jq to produce a JSON string of the file contents
if ! CONTENT_JSON=$(jq -Rs '.' "$SCRIPT_PATH"); then
  echo "❌ Failed to read or JSON-encode $SCRIPT_PATH" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# 5) Register (or skip) the resource
# -----------------------------------------------------------------------------
echo "📦 Registering resource '$RESOURCE_ID' → $SCRIPT_PATH"
RES_PAYLOAD=$(
  jq -n \
    --arg id "$RESOURCE_ID" \
    --arg name "$SCRIPT_NAME" \
    --arg type "file" \
    --argjson content "$CONTENT_JSON" \
    '{id: $id, name: $name, type: $type, content: $content}'
)
RES_RESP=$(curl -s -X POST http://localhost:4444/resources \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$RES_PAYLOAD" \
  -w "\n%{http_code}")
RES_BODY=$(printf "%s" "$RES_RESP" | sed '$d')
RES_STATUS=$(printf "%s" "$RES_RESP" | tail -n1)

if [[ "$RES_STATUS" -ge 200 && "$RES_STATUS" -lt 300 ]]; then
  echo "✅ Resource registered (HTTP $RES_STATUS)"
elif [[ "$RES_STATUS" -eq 409 || ("$RES_STATUS" -eq 422 && "$RES_BODY" == *"already exists"*) ]]; then
  echo "⚠️  Resource already exists, skipping."
else
  echo "❌ Resource registration failed (HTTP $RES_STATUS):" >&2
  echo "$RES_BODY" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# 6) Register (or skip) the server pointing to that resource
# -----------------------------------------------------------------------------
echo "🚀 Registering hello-world-agent server…"
SV_PAYLOAD=$(
  jq -n \
    --arg name "hello-world-agent" \
    --arg desc "A simple demo agent that echoes back input." \
    --argjson tools '["echo"]' \
    --argjson resources "[\"'"$RESOURCE_ID"'"\]" \
    --argjson prompts '[]' \
    '{ name: $name, description: $desc,
       associated_tools: $tools,
       associated_resources: $resources,
       associated_prompts: $prompts }'
)
SV_RESP=$(curl -s -X POST http://localhost:4444/servers \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$SV_PAYLOAD" \
  -w "\n%{http_code}")
SV_BODY=$(printf "%s" "$SV_RESP" | sed '$d')
SV_STATUS=$(printf "%s" "$SV_RESP" | tail -n1)

if [[ "$SV_STATUS" -ge 200 && "$SV_STATUS" -lt 300 ]]; then
  echo "✅ Server registered (HTTP $SV_STATUS)"
elif [[ "$SV_STATUS" -eq 409 || ("$SV_STATUS" -eq 422 && "$SV_BODY" == *"already exists"*) ]]; then
  echo "⚠️  Server already exists, skipping."
else
  echo "❌ Server registration failed (HTTP $SV_STATUS):" >&2
  echo "$SV_BODY" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# 7) Verify registration
# -----------------------------------------------------------------------------
echo "🔍 Fetching registered servers…"
curl -s \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:4444/servers \
| jq .
