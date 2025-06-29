#!/bin/bash

# ==============================================================================
# 🚀 MCP Gateway Launcher - Root Script
# ==============================================================================
# This script should be run from the directory that CONTAINS the
# 'mcp-watsonx-tutorial' project folder.
#
# It navigates into 'mcp-watsonx-tutorial/mcpgateway', sets up and activates
# the Python virtual environment located at 'mcp-watsonx-tutorial/.venv',
# and starts the MCP Gateway service.
# ==============================================================================

# --- Define Colors for Output ---
COLOR_BLUE="\033[1;34m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_RED="\033[1;31m"
COLOR_RESET="\033[0m"

# --- Function for printing styled messages ---
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}▶ ${message}${COLOR_RESET}"
}

# --- Step 1: Navigate to Gateway Directory ---
# The script assumes it's run from the parent of mcp-watsonx-tutorial
PROJECT_DIR="mcp-watsonx-tutorial"
GATEWAY_DIR="$PROJECT_DIR/mcpgateway"
print_message "$COLOR_BLUE" "Checking for gateway directory at '$GATEWAY_DIR'..."

if [ ! -d "$GATEWAY_DIR" ]; then
    print_message "$COLOR_RED" "Error: Directory '$GATEWAY_DIR' not found."
    print_message "$COLOR_YELLOW" "Please ensure you are running this script from the directory containing 'mcp-watsonx-tutorial'."
    exit 1
fi

# We will activate the environment from the project root, then cd into the gateway dir
print_message "$COLOR_GREEN" "Project root validated."

# --- Step 2: Check for, Create, and Activate Virtual Environment ---
# The virtual environment is now located in the project root
VENV_PATH="$PROJECT_DIR/.venv"
print_message "$COLOR_BLUE" "Checking for virtual environment at '$VENV_PATH'..."

if [ ! -f "$VENV_PATH/bin/activate" ]; then
    print_message "$COLOR_YELLOW" "Virtual environment not found."
    read -p "Would you like to create it and install dependencies now? (y/n) " -n 1 -r
    echo "" # Move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_message "$COLOR_BLUE" "Creating virtual environment at '$VENV_PATH'..."
        if ! python3 -m venv "$VENV_PATH"; then
            print_message "$COLOR_RED" "Failed to create virtual environment. Please ensure Python 3 is installed correctly."
            exit 1
        fi

        print_message "$COLOR_BLUE" "Activating environment and installing gateway dependencies..."
        # Activate and install. Note: pip install -e requires being in the correct directory.
        (
            source "$VENV_PATH/bin/activate" && \
            pip install --upgrade pip && \
            pip install -e "$GATEWAY_DIR"
        )

        if [ $? -ne 0 ]; then
            print_message "$COLOR_RED" "Failed to install dependencies. Please check for errors above."
            exit 1
        fi
        print_message "$COLOR_GREEN" "Setup complete."
    else
        print_message "$COLOR_RED" "Aborting. Please set up the virtual environment manually."
        exit 1
    fi
fi

print_message "$COLOR_GREEN" "Activating virtual environment."
source "$VENV_PATH/bin/activate"

# --- Step 3: Set Environment Variables ---
print_message "$COLOR_BLUE" "Setting required environment variables..."

export BASIC_AUTH_USERNAME=admin
export BASIC_AUTH_PASSWORD=changeme
export JWT_SECRET_KEY=my-super-secret-key

print_message "$COLOR_GREEN" "Environment variables set."
echo "  • BASIC_AUTH_USERNAME: $BASIC_AUTH_USERNAME"
echo "  • JWT_SECRET_KEY: [set]"

# --- Step 4: Start the MCP Gateway ---
# Navigate into the gateway directory just before running the command
cd "$GATEWAY_DIR"
print_message "$COLOR_BLUE" "Starting MCP Gateway on http://0.0.0.0:4444 from '$(pwd)'..."
echo "--------------------------------------------------------"

mcpgateway --host 0.0.0.0 --port 4444

echo "--------------------------------------------------------"
print_message "$COLOR_RED" "MCP Gateway has shut down."
