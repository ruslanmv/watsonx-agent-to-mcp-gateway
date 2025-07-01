#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# 1) Activate the project’s Python virtualenv
# -----------------------------------------------------------------------------
if [ -f "./mcpgateway/.venv/bin/activate" ]; then
  # shellcheck disable=SC1090
  source ./mcpgateway/.venv/bin/activate
  echo "✅ Activated Python environment from ./mcpgateway/.venv/bin/activate"
else
  echo "❌ Virtualenv not found at ./mcpgateway/.venv/bin/activate; please run your setup/start scripts first."
  exit 1
fi

# -----------------------------------------------------------------------------
# 2) Ensure env-vars are set (fall back to defaults if not)
# -----------------------------------------------------------------------------
export BASIC_AUTH_USER="${BASIC_AUTH_USER:-admin}"
export BASIC_AUTH_PASSWORD="${BASIC_AUTH_PASSWORD:-changeme}"
export JWT_SECRET_KEY="${JWT_SECRET_KEY:-my-test-key}"

# -----------------------------------------------------------------------------
# 3) Generate a short-lived JWT using the gateway’s utility
# -----------------------------------------------------------------------------
echo "🔑 Generating JWT token…"
ADMIN_TOKEN=$(
  JWT_SECRET_KEY="$JWT_SECRET_KEY" \
    python3 -m mcpgateway.utils.create_jwt_token \
      --username "$BASIC_AUTH_USER" \
      --exp 60 \
      --secret "$JWT_SECRET_KEY"
)
export ADMIN_TOKEN

# -----------------------------------------------------------------------------
# 4) Call the /servers endpoint with Bearer auth
# -----------------------------------------------------------------------------
echo "🌐 Querying /servers with Bearer token…"
curl -s \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:4444/servers \
| jq .
