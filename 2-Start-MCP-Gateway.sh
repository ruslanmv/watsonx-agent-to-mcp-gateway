#!/usr/bin/env bash
#2-Start-MCP-Gateway.sh
set -euo pipefail

# -----------------------------------------------------------------------------
# Determine script & project paths
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/mcpgateway"
VENV_ACTIVATE="${PROJECT_DIR}/.venv/bin/activate"

# -----------------------------------------------------------------------------
# 1) Activate Python venv immediately
# -----------------------------------------------------------------------------
if [ ! -f "${VENV_ACTIVATE}" ]; then
  echo "❌ virtualenv not found at ${VENV_ACTIVATE}" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "${VENV_ACTIVATE}"
echo "✅ Activated Python environment from ${VENV_ACTIVATE}"

# -----------------------------------------------------------------------------
# 2) Locate .env (root first, then project)
# -----------------------------------------------------------------------------
ENV_FILE_ROOT="${SCRIPT_DIR}/.env"
ENV_FILE_PROJECT="${PROJECT_DIR}/.env"
if [ -f "${ENV_FILE_ROOT}" ]; then
  ENV_FILE="${ENV_FILE_ROOT}"
elif [ -f "${ENV_FILE_PROJECT}" ]; then
  ENV_FILE="${ENV_FILE_PROJECT}"
else
  ENV_FILE=""
fi

# -----------------------------------------------------------------------------
# 3) Ensure .env exists
# -----------------------------------------------------------------------------
if [ -z "${ENV_FILE}" ]; then
  echo "ℹ️  No .env found in ${SCRIPT_DIR} or ${PROJECT_DIR}."
  if [ -f "${PROJECT_DIR}/.env.example" ]; then
    echo "ℹ️  Copying .env.example to ${PROJECT_DIR}/.env so you can configure it…"
    cp "${PROJECT_DIR}/.env.example" "${PROJECT_DIR}/.env"
    echo "✅ Created ${PROJECT_DIR}/.env from example. Please edit it (set BASIC_AUTH_USERNAME, BASIC_AUTH_PASSWORD, JWT_SECRET_KEY, etc.) and re-run this script."
    exit 0
  else
    echo "❌ No .env or .env.example available; cannot continue." >&2
    exit 1
  fi
fi
echo "✅ Using .env file at: ${ENV_FILE}"

# -----------------------------------------------------------------------------
# 4) Load environment variables
# -----------------------------------------------------------------------------
# shellcheck disable=SC2046
export $(grep -v '^\s*#' "${ENV_FILE}" | xargs)
echo "✅ Loaded environment variables from ${ENV_FILE}"

# -----------------------------------------------------------------------------
# 5) Check port availability
# -----------------------------------------------------------------------------
if ss -tunlp 2>/dev/null | grep -q ':${PORT:-4444}'; then
  echo "⚠️  Port ${PORT:-4444} is already in use."
  read -r -p "Stop the existing MCP Gateway and continue? [y/N] " confirm
  if [[ "${confirm,,}" == "y" ]]; then
    echo "Stopping existing MCP Gateway…"
    pkill -f "mcpgateway --host ${HOST:-0.0.0.0} --port ${PORT:-4444}" || true
    sleep 1
  else
    echo "Aborting startup."
    exit 1
  fi
fi

# -----------------------------------------------------------------------------
# 6) Change into project dir so Python can find the mcpgateway module
# -----------------------------------------------------------------------------
cd "${PROJECT_DIR}"

# -----------------------------------------------------------------------------
# 7) Initialize the database
# -----------------------------------------------------------------------------
echo "⏳ Initializing database (creating tables)…"
python -m mcpgateway.db
echo "✅ Database initialized."

# -----------------------------------------------------------------------------
# 8) Start the MCP Gateway
# -----------------------------------------------------------------------------
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-4444}"

echo "🎯 Starting MCP Gateway on ${HOST}:${PORT} with user '${BASIC_AUTH_USERNAME:-admin}'…"
mcpgateway --host "${HOST}" --port "${PORT}" &
echo "✅ MCP Gateway started (PID: $!)"
