#!/bin/bash

#5-start-watsonx-agent.sh
# A simple script to start the watsonx-agent server.
#

# --- Configuration ---
# Set the full path to your project directory.
# Please update this path if you move your project.
PROJECT_DIR="./agents/watsonx-agent"

# --- Script Execution ---

echo "Navigating to the project directory..."
# Change to the project directory. If this fails, the script will exit.
cd "$PROJECT_DIR" || { echo "Error: Could not change to directory $PROJECT_DIR. Please check the path."; exit 1; }

echo "Activating Python virtual environment..."
# Activate the virtual environment.
# The 'source' command executes the script in the current shell.
source .venv/bin/activate || { echo "Error: Failed to activate the virtual environment. Make sure it exists at '.venv/bin/activate'."; exit 1; }

echo "Starting the watsonx-agent server..."
# Run the Python server.
# The script will continue to run this command until it is manually stopped (e.g., with Ctrl+C).
python server_sse.py

echo "Server has been stopped."