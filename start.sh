#!/usr/bin/env bash
set -euo pipefail

# 1) Activate your Gateway venv
source ./mcpgateway/.venv/bin/activate

# 2) Basic‐Auth creds & JWT secret
: "${BASIC_AUTH_USER:=admin}"
: "${BASIC_AUTH_PASSWORD:=changeme}"
: "${JWT_SECRET_KEY:=my-test-key}"

# 3) Mint a 60s admin JWT
ADMIN_TOKEN=$(
  JWT_SECRET_KEY="$JWT_SECRET_KEY" \
    python3 -m mcpgateway.utils.create_jwt_token \
      --username "$BASIC_AUTH_USER" \
      --secret   "$JWT_SECRET_KEY" \
      --exp      60
)
echo "🔑 ADMIN_TOKEN generated"

# 4) Register the agent script as a Resource via JSON API
RES_URI="watsonx-agent-script"
SCRIPT_PATH="agents/watsonx-agent/server.py"
echo "📦 Registering resource $RES_URI → $SCRIPT_PATH"

# Build a JSON payload, embedding the file‐content (as a text blob).
# jq -Rs will slurp the file and escape it correctly as a JSON string.
read -r -d '' RESOURCE_PAYLOAD <<EOF
$(jq -Rs \
    --arg uri "$RES_URI" \
    --arg name "$RES_URI" \
    --arg desc "Watsonx MCP STDIO‐based agent script" \
    --arg mime "application/x-python" \
    '{
       uri:      $uri,
       name:     $name,
       description: $desc,
       mime_type:   $mime,
       template:    null,
       content:     .
     }' "$SCRIPT_PATH")
EOF

# POST it and grab the numeric `id` out of the JSON response
RESOURCE_JSON=$(curl -s -X POST http://localhost:4444/resources \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$RESOURCE_PAYLOAD")

RES_ID=$(echo "$RESOURCE_JSON" | jq -r '.id')
echo "➡️  Resource registered with id = $RES_ID"

# 5) Register the Server, pointing at that numeric resource ID
echo "🚀 Registering watsonx-agent server…"
curl -v -X POST http://localhost:4444/servers \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
        "name":               "watsonx-agent",
        "description":        "A Watsonx.ai-backed STDIO agent exposing chat",
        "icon":               null,
        "associated_tools":   ["chat"],
        "associated_resources":["'"$RES_ID"'"],
        "associated_prompts":  []
      }' \
  && echo "✅ Server registered" \
  || echo "⚠️  Server may already exist or failed validation"

# 6) List all servers
echo "🔍 Servers now:"
curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
     http://localhost:4444/servers | jq .
