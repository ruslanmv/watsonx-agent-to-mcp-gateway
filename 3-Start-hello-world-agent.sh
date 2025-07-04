#!/bin/bash

# 3-Start-hello-world-agent.sh
# A simple script to start the hello_world agent server.
# This script assumes it is being run from the root of the project directory.

# --- Configuration ---
# Set the path to the agent's directory.
AGENT_DIR="./agents/hello_world"
# Set the path to the shared virtual environment activate script.
VENV_PATH="./mcpgateway/.venv/bin/activate"
# The python script to run as the server.
SERVER_SCRIPT="hello_server_sse.py"


# --- Script Execution ---

echo "Activating Python virtual environment from $VENV_PATH..."
# Activate the virtual environment.
# The 'source' command executes the script in the current shell.
source "$VENV_PATH" || { echo "Error: Failed to activate the virtual environment. Make sure it exists at '$VENV_PATH'."; exit 1; }

echo "Navigating to the agent directory: $AGENT_DIR..."
# Change to the project directory. If this fails, the script will exit.
cd "$AGENT_DIR" || { echo "Error: Could not change to directory $AGENT_DIR. Please check the path."; exit 1; }

echo "Starting the hello_world agent server ($SERVER_SCRIPT)..."
# Run the Python server.
# The script will continue to run this command until it is manually stopped (e.g., with Ctrl+C).
python "$SERVER_SCRIPT"

echo "Server has been stopped."