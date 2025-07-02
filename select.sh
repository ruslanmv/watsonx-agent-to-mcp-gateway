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

# 4) Fetch active servers and store their details in arrays
echo "Fetching active servers..."

# Get the raw JSON of servers that have "isActive": true
ACTIVE_SERVERS_JSON=$(
    curl -s \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        http://localhost:4444/servers |
        jq '[.[] | select(.isActive == true)]'
)

# Check if any active servers were found
if [[ "$(echo "$ACTIVE_SERVERS_JSON" | jq 'length')" -eq 0 ]]; then
    echo "No active servers found."
    exit 1
fi

# Populate arrays with server names and IDs using mapfile
mapfile -t SERVER_NAMES < <(echo "$ACTIVE_SERVERS_JSON" | jq -r '.[].name')
mapfile -t SERVER_IDS < <(echo "$ACTIVE_SERVERS_JSON" | jq -r '.[].id')

# 5) Display servers and prompt for selection
echo "Please select a server:"
for i in "${!SERVER_NAMES[@]}"; do
    printf "%d) %s\n" "$((i + 1))" "${SERVER_NAMES[$i]}"
done
echo "----------------------------------------"

# 6) Get user input, with 1 as the default
read -p "Enter number (default is 1): " selection
selection=${selection:-1} # Set default to 1 if input is empty

# 7) Validate input and export the selected SERVER_ID
chosen_index=$((selection - 1))

# Check if the selection is a valid number within the range of our array
if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$chosen_index" -ge 0 ] && [ "$chosen_index" -lt "${#SERVER_IDS[@]}" ]; then
    # Export the chosen server ID
    export SERVER_ID="${SERVER_IDS[$chosen_index]}"
    
    echo
    echo "✅ Server selected: '${SERVER_NAMES[$chosen_index]}'"
    echo "✅ Exporting environment variable: SERVER_ID=${SERVER_ID}"
    echo
else
    echo "❌ Invalid selection: $selection. Please run the script again."
    exit 1
fi

# You can now use the $SERVER_ID for other commands
# Example:
# echo "Pinging selected server: $SERVER_ID"
# curl -H "Authorization: Bearer $ADMIN_TOKEN" http://localhost:4444/servers/$SERVER_ID