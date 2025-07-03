#!/usr/bin/env bash
set -euxo pipefail

# 1) Activate the Gateway venv
source ./mcpgateway/.venv/bin/activate

# 2) Set creds & JWT secret (or override via env)
: "${BASIC_AUTH_USER:=admin}"
: "${BASIC_AUTH_PASSWORD:=changeme}"
: "${JWT_SECRET_KEY:=my-test-key}"

# 3) Mint a short-lived admin JWT (60s)
ADMIN_TOKEN=$(
  JWT_SECRET_KEY="$JWT_SECRET_KEY" \
    python3 -m mcpgateway.utils.create_jwt_token \
      --username "$BASIC_AUTH_USER" \
      --secret   "$JWT_SECRET_KEY" \
      --exp      60
)
echo "🔑 ADMIN_TOKEN generated"

# 4) Register the agent script as a Resource
RESOURCE_URI="watsonx-agent-script"
SCRIPT_PATH="agents/watsonx-agent/server.py"
echo "📦 Registering resource $RESOURCE_URI → $SCRIPT_PATH"

RAW_RESPONSE=$(
  jq -Rs \
    --arg uri "$RESOURCE_URI" \
    --arg name "$RESOURCE_URI" \
    --arg desc "Watsonx MCP STDIO agent script" \
    --arg mime "application/x-python" \
    '{
       uri:         $uri,
       name:        $name,
       description: $desc,
       mime_type:   $mime,
       template:    null,
       content:     .
     }' "$SCRIPT_PATH" \
  | curl -v -i --fail \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d @- \
      http://localhost:4444/resources
)

echo "---- raw RESOURCE response ----"
echo "$RAW_RESPONSE"
echo "--------------------------------"

# Extract status and body
HTTP_STATUS=$(printf '%s' "$RAW_RESPONSE" \
  | sed -n 's/^HTTP\/.* \([0-9]\{3\}\).*$/\1/p' \
  | head -n1 || echo "unknown")
BODY=$(printf '%s' "$RAW_RESPONSE" \
  | sed '/^HTTP\/.* /,/^\r*$/d' \
  | sed '/^\r*$/d')

echo "HTTP status: $HTTP_STATUS"
echo "Response body: $BODY"

if [[ "$HTTP_STATUS" != "200" && "$HTTP_STATUS" != "201" ]]; then
  echo "❌ Resource registration failed (status $HTTP_STATUS)" >&2
  exit 1
fi

RES_ID=$(printf '%s' "$BODY" | jq -r '.id')
echo "➡️  Resource registered with id=$RES_ID"

# 5) Register the Server (omit tools so discovery can populate chat)
echo "🚀 Registering watsonx-agent server…"
SERVER_PAYLOAD=$(
  jq -n \
    --arg name "watsonx-agent" \
    --arg description "A Watsonx.ai-backed STDIO agent exposing chat" \
    --argjson resources "[${RES_ID}]" \
    --argjson prompts "[]" \
    '{
       name:                 $name,
       description:          $description,
       icon:                 null,
       associated_tools:     [],
       associated_resources: $resources,
       associated_prompts:   $prompts
     }'
)

echo "→ Server payload: $SERVER_PAYLOAD"

SERVER_RESPONSE=$(
  echo "$SERVER_PAYLOAD" \
  | curl -v -i --fail \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -H "Content-Type: application/json" \
      -d @- \
      http://localhost:4444/servers
)

echo "---- raw SERVER response ----"
echo "$SERVER_RESPONSE"
echo "--------------------------------"

SERVER_ID=$(printf '%s' "$SERVER_RESPONSE" \
  | sed -n 's/^HTTP\/.* \([0-9]\{3\}\).*$/\1/p' \
  | head -n1 \
  && printf '%s' "$SERVER_RESPONSE" | sed '/^HTTP\/.* /,/^\r*$/d' | jq -r '.id')
echo "✅ Server registered with id=$SERVER_ID"

# 6) Trigger on-demand discovery
echo "🔍 Triggering discovery for server $SERVER_ID"
curl -v --fail -X POST \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:4444/servers/${SERVER_ID}/discovery \
  && echo "✅ Discovery triggered"

# 7) List all servers (you should now see the 'chat' tool)
echo "🔍 Servers now:"
curl -v --fail \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:4444/servers | jq .
