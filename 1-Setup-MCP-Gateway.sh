#!/usr/bin/env bash
#1-Setup-MCP-Gateway.sh
set -euo pipefail

# -----------------------------------------------------------------------------
# 1) Determine base directory (where this script is run)
# -----------------------------------------------------------------------------
BASE_DIR="$(pwd)"
PROJECT_DIR="${BASE_DIR}/mcpgateway"
VENV_DIR="${PROJECT_DIR}/.venv"

# -----------------------------------------------------------------------------
# 2) Check Ubuntu version
# -----------------------------------------------------------------------------
if ! grep -q "22.04" /etc/os-release; then
  echo "⚠️  Warning: this script targets Ubuntu 22.04; you may run into issues on other versions."
fi

# -----------------------------------------------------------------------------
# 3) Update & install system packages
# -----------------------------------------------------------------------------
echo "⏳ Updating package lists…"
sudo apt-get update

echo "⏳ Installing prerequisites (git, curl, jq)…"
sudo apt-get install -y git curl jq

echo "⏳ Installing Python 3.11 and venv support…"
sudo apt-get install -y python3.11 python3.11-venv python3.11-dev build-essential

# -----------------------------------------------------------------------------
# 4) Clone or update the repo
# -----------------------------------------------------------------------------
if [ ! -d "${PROJECT_DIR}/.git" ]; then
  echo "⏳ Cloning mcp-context-forge into ${PROJECT_DIR}…"
  git clone https://github.com/IBM/mcp-context-forge.git "${PROJECT_DIR}"
else
  echo "🔄 Repo already exists; fetching latest changes…"
  pushd "${PROJECT_DIR}" >/dev/null
    git fetch --all
    git pull --ff-only
  popd >/dev/null
fi

# -----------------------------------------------------------------------------
# 5) Create or reuse Python virtualenv
# -----------------------------------------------------------------------------
if [ -d "${VENV_DIR}" ]; then
  read -r -p "⚠️  Virtualenv already exists at ${VENV_DIR}. Overwrite it? [y/N] " resp
  if [[ "${resp,,}" == "y" ]]; then
    echo "🗑  Removing existing virtualenv…"
    rm -rf "${VENV_DIR}"
    echo "⏳ Creating fresh virtualenv at ${VENV_DIR}…"
    python3.11 -m venv "${VENV_DIR}"
  else
    echo "✅ Reusing existing virtualenv."
  fi
else
  echo "⏳ Creating virtualenv at ${VENV_DIR}…"
  python3.11 -m venv "${VENV_DIR}"
fi

# -----------------------------------------------------------------------------
# 6) Activate the venv & upgrade packaging tools
# -----------------------------------------------------------------------------
# shellcheck disable=SC1090
source "${VENV_DIR}/bin/activate"
echo "⏳ Upgrading pip, setuptools, wheel…"
pip install --upgrade pip setuptools wheel

# -----------------------------------------------------------------------------
# 7) Install project dependencies (including dev extras)
# -----------------------------------------------------------------------------
pushd "${PROJECT_DIR}" >/dev/null

if [ -f "pyproject.toml" ]; then
  echo "⏳ Installing project in editable mode with dev extras…"
  pip install -e '.[dev]'
elif [ -f "requirements.txt" ]; then
  echo "⏳ Installing from requirements.txt…"
  pip install -r requirements.txt
else
  echo "ℹ️  No pyproject.toml or requirements.txt found; skipping dependency install."
fi

# -----------------------------------------------------------------------------
# 8) Copy example env file if needed
# -----------------------------------------------------------------------------
if [ -f ".env.example" ] && [ ! -f ".env" ]; then
  echo "⏳ Copying .env.example to .env…"
  cp .env.example .env
  echo "✅ Created .env – please review and customize it before first run."
fi

popd >/dev/null

echo -e "\n🎉 Setup complete!
Next steps:
  cd ${PROJECT_DIR}
  source .venv/bin/activate
  # then you can run ../start-mcp-gateway.sh to initialize DB & launch the gateway
"
