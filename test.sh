#!/usr/bin/env bash
set -euo pipefail

# 1) Activate venv
# Ensure the path to your virtual environment is correct
if [ -f "./mcpgateway/.venv/bin/activate" ]; then
    source ./mcpgateway/.venv/bin/activate
else
    echo "Virtual environment not found."
    exit 1
fi

# --- Credentials (set your password here) ---
export BASIC_AUTH_USER="${BASIC_AUTH_USER:-admin}"
export BASIC_AUTH_PASSWORD="${BASIC_AUTH_PASSWORD:-adminpw}"
export JWT_SECRET_KEY="${JWT_SECRET_KEY:-my-test-key}"

# --- Mint an Admin JWT ---
ADMIN_TOKEN=$(
  python3 -m mcpgateway.utils.create_jwt_token \
    --username "$BASIC_AUTH_USER" \
    --secret   "$JWT_SECRET_KEY" \
    --exp      60
)

# --- Find and Export the Server ID ---
echo "🔎 Searching for active 'watsonx-agent'..."
SERVER_ID=$(
  curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
       http://localhost:4444/servers | \
  jq -r '.[] | select(.name=="watsonx-agent" and .isActive==true) | .id'
)

# --- Validate and Confirm ---
if [[ -z "$SERVER_ID" ]]; then
  echo "❌ Could not find an active server named 'watsonx-agent'."
  exit 1
fi

echo "✅ Agent found! Exporting SERVER_ID=${SERVER_ID}"
export SERVER_ID