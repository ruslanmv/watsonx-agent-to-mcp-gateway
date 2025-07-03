#!/bin/bash

#6-Test-WatsonX-agent.sh
# A simple script to run the watsonx-agent tests.
#

# --- Configuration ---
# Set the full path to your watsonx-agent directory.
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

echo "Navigating to the test directory..."
# Change to the test directory, which is expected to be inside the project directory.
cd test || { echo "Error: Could not change to directory 'test'. Make sure it exists inside $PROJECT_DIR."; exit 1; }

echo "Running the Python test script..."
# Run the Python test script.
python test_sse.py

echo "Test script has finished."