# Makefile
.PHONY: setup run docker-build docker-run clean

VENV_NAME := .venv
VENV_STAMP_FILE := $(VENV_NAME)/.setup_complete

# This target represents a complete and up-to-date virtual environment.
# It depends on requirements.txt, so it will re-run if the requirements change.
$(VENV_STAMP_FILE): requirements.txt
	@echo "Setting up or updating Python virtual environment in $(VENV_NAME)..."
	@python3 -m venv $(VENV_NAME)
	@$(VENV_NAME)/bin/pip install --upgrade pip
	@$(VENV_NAME)/bin/pip install -r requirements.txt
	@echo "Setup complete."
	@touch $(VENV_STAMP_FILE) # Create a stamp file to mark completion

# A user-friendly alias to trigger the setup process.
setup: $(VENV_STAMP_FILE)

# The 'run' target now depends on the stamp file, guaranteeing that
# the virtual environment is fully set up before it runs.
run: $(VENV_STAMP_FILE)
	@echo "Starting Watsonx Chat Agent on http://localhost:8082..."
	@$(VENV_NAME)/bin/uvicorn main:app --host 0.0.0.0 --port 8082

docker-build:
	@echo "Building Docker image..."
	@docker build -t watsonx-agent:latest .

docker-run:
	@echo "Running Docker container..."
	@docker run --rm -p 8082:8082 --env-file .env watsonx-agent:latest

clean:
	@echo "Removing virtual environment..."
	@rm -rf $(VENV_NAME)