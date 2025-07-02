#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# list_agents.sh
# -----------------------------------------------------------------------------
# Usage:
#   ./list_agents.sh [<ADMIN_TOKEN>]
#
# You can either pass your JWT as the first argument, or export it:
#   export MCP_ADMIN_TOKEN="$(./get_token.sh | tail -n1)"
#   ./list_agents.sh
#
# Output columns: ID, Name, Description, URL, Transport
# -----------------------------------------------------------------------------

# Grab token from env or first argument
if [[ -n "${MCP_ADMIN_TOKEN:-}" ]]; then
  TOKEN="$MCP_ADMIN_TOKEN"
elif [[ $# -ge 1 ]]; then
  TOKEN="$1"
else
  echo "Usage: $0 [<ADMIN_TOKEN>]" >&2
  echo "Or set MCP_ADMIN_TOKEN environment variable" >&2
  exit 1
fi

# Fetch & format
curl -sS -X GET "http://localhost:4444/gateways?include_inactive=false" \
     -H "Authorization: Bearer ${TOKEN}" \
     -H "Accept: application/json" \
| jq -r '
    # print header
    (["ID","Name","Description","URL","Transport"] | @tsv),
    # for each gateway, extract fields (fallback to "-")
    ( .[] |
      [
        .id,
        (.name       // "-"),
        (.description// "-"),
        (.url        // "-"),
        (.transport  // "-")
      ] | @tsv
    )
' | column -t -s $'\t'
