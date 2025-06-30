# Makefile
.PHONY: all setup run lint fmt test docker-build docker-run clean

# Virtual-env location and stamp file
VENV         := .venv
STAMP        := $(VENV)/.setup_complete
PYTHON       := $(VENV)/bin/python
PIP          := $(VENV)/bin/pip

# Default to setting up the environment
all: setup

# Recreate venv and reinstall if requirements.txt changes
$(STAMP): requirements.txt
	@echo "🔧 Creating/updating virtual environment in $(VENV)…"
	@python3.11 -m venv $(VENV)
	@$(PIP) install --upgrade pip
	@$(PIP) install --no-cache-dir -r requirements.txt
	@touch $(STAMP)
	@echo "✅ Virtual environment is ready."

# Alias for the venv setup
setup: $(STAMP)

# Run your Watsonx Agent (stdio MCP server)
run: setup
	@echo "🚀 Starting Watsonx Agent (stdio)…"
	@$(PYTHON) server.py

# Lint with flake8
lint: setup
	@echo "🔍 Running flake8…"
	@$(VENV)/bin/flake8 .

# Format with Black
fmt: setup
	@echo "🎨 Formatting with black…"
	@$(VENV)/bin/black .

# Run tests
test: setup
	@echo "🧪 Running pytest…"
	@$(VENV)/bin/pytest -q

# Build the Docker image
docker-build:
	@echo "🐳 Building Docker image watsonx-agent:latest…"
	@docker build -t watsonx-agent:latest .

# Run the Docker container (stdin/stdout)
docker-run:
	@echo "🐳 Running Docker container…"
	@docker run --rm -it \
		--env-file .env \
		--name watsonx-agent \
		watsonx-agent:latest

# Clean out the virtual environment
clean:
	@echo "🧹 Removing virtual environment…"
	@rm -rf $(VENV)
