#!/usr/bin/env bash
set -euo pipefail

# 1. Ensure python3 is installed
if ! command -v python3 &> /dev/null; then
  echo "➡️  python3 not found. Installing..."
  if [ -f /etc/debian_version ]; then
    sudo apt update
    sudo apt install -y python3 python3-venv python3-pip
  elif [ -f /etc/redhat-release ]; then
    sudo yum install -y python3 python3-venv python3-pip
  else
    echo "❌ Unsupported OS. Please install Python3 manually."
    exit 1
  fi
fi

# 2. Create a virtual environment in ./.venv
echo "➡️  Creating virtualenv in ./.venv"
python3 -m venv .venv

# 3. Activate it and upgrade pip
echo "➡️  Activating .venv and upgrading pip"
# shellcheck disable=SC1091
source .venv/bin/activate
pip install --upgrade pip

# 4. Install dependencies if a requirements.txt exists
if [ -f requirements.txt ]; then
  echo "➡️  Installing dependencies from requirements.txt"
  pip install -r requirements.txt
fi

echo
echo "✅ Setup complete!"
echo "To start using your Python environment, run:"
echo
echo "    source .venv/bin/activate"
echo
