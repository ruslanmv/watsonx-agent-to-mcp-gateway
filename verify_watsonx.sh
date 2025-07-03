#!/usr/bin/env bash
set -euo pipefail

# 1) Activate venv
source ./mcpgateway/.venv/bin/activate

# 2) Ensure creds
export BASIC_AUTH_USER="${BASIC_AUTH_USER:-admin}"
export JWT_SECRET_KEY="${JWT_SECRET_KEY:-my-test-key}"

# 3) Mint JWT
ADMIN_TOKEN=$(
  JWT_SECRET_KEY="$JWT_SECRET_KEY" \
    python3 -m mcpgateway.utils.create_jwt_token \
      --username "$BASIC_AUTH_USER" \
      --secret   "$JWT_SECRET_KEY" \
      --exp      60
)

# 4) List servers & their tools
curl -s \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:4444/servers \
| jq .

