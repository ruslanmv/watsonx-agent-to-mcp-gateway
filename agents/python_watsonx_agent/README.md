# 🤖 Watsonx.ai Chatbot Agent

> A simple Python-based MCP agent that provides chat capabilities using the `ibm-watsonx-ai` SDK.

## Features

  * Implements a **`chat`** tool that connects to IBM's `watsonx.ai`
  * Uses the powerful `ibm/granite-13b-instruct-v2` model
  * Built with FastAPI for a robust HTTP (JSON-RPC) transport at `/http`
  * Securely configures credentials via a `.env` file
  * Includes a Makefile for easy setup, execution, and containerization

## Prerequisites

  * Python 3.9+
  * An [IBM Cloud Account](https://cloud.ibm.com/) with a `watsonx.ai` instance.
  * Your `watsonx.ai` API Key, Project ID, and region URL.

## Quick Start & Usage

1.  **Create Project Files:**
    First, create a directory for your agent. Inside it, create the `main.py`, `requirements.txt`, `Makefile`, and `.env.example` files with the code provided in the sections below.

2.  **Set Up Credentials:**
    Rename `.env.example` to `.env` and fill in your actual `watsonx.ai` credentials.

    ```bash
    mv .env.example .env
    # Now edit the .env file
    ```

3.  **Set Up Environment & Run:**
    From your terminal, the `make setup` command will create a Python virtual environment and install all dependencies. Then, `make run` will start the agent.

    ```bash
    # This only needs to be run once
    make setup

    # Start the agent
    make run
    ```

    You will see output similar to this, and the server will be running:

    ```
    INFO:     Started server process [12345]
    INFO:     Waiting for application startup.
    INFO:     Application startup complete.
    INFO:     Uvicorn running on http://0.0.0.0:8082 (Press CTRL+C to quit)
    ```

4.  **Query the Agent:**
    **Open a new, separate terminal window.** With the server running, use `curl` in the second terminal to send a prompt to your chatbot.

    ```bash
    curl -X POST \
      -H "Content-Type: application/json" \
      -d '{"tool": "chat", "args": {"prompt": "Write a short poem about AI."}}' \
      http://localhost:8082/http
    ```

5.  **See the Result:**
    The agent will return the response from `watsonx.ai`:

    ```json
    {"result":"In lines of code, a mind takes flight,\nA silent whisper in the night..."}
    ```

## Source Code

### `.env.example`

Create this file to guide users. They will rename it to `.env` and add their secrets.

```env
# Your Watsonx.ai API Key from IBM Cloud IAM
WATSONX_APIKEY="your_api_key_here"

# The URL for your Watsonx.ai region (e.g., https://us-south.ml.cloud.ibm.com)
WATSONX_URL="your_watsonx_url_here"

# Your Watsonx.ai Project ID
PROJECT_ID="your_project_id_here"
```

### `requirements.txt`

```text
fastapi
uvicorn
python-dotenv
ibm-watsonx-ai
```

### `main.py`

```python
"""
main.py – Minimal, robust Watsonx Chat Agent
"""

from __future__ import annotations

import logging
import os
from functools import lru_cache
from typing import Final, Optional

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, HTTPException, status
from pydantic import BaseModel

# --------------------------------------------------------------------------- #
# IBM Watsonx SDK imports
# --------------------------------------------------------------------------- #
try:
    from ibm_watsonx_ai.credentials import Credentials
    from ibm_watsonx_ai.foundation_models import ModelInference
    from ibm_watsonx_ai.metanames import GenTextParamsMetaNames as GenParams
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        "The package `ibm-watsonx-ai` is required. "
        "Install it with `pip install ibm-watsonx-ai`."
    ) from exc

# --------------------------------------------------------------------------- #
# Logging
# --------------------------------------------------------------------------- #
logging.basicConfig(
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    level=logging.INFO,
)
logger: Final = logging.getLogger("watsonx-agent")

# --------------------------------------------------------------------------- #
# Configuration
# --------------------------------------------------------------------------- #
load_dotenv()  # .env support

WATSONX_APIKEY: Final[str | None] = os.getenv("WATSONX_APIKEY")
WATSONX_URL:    Final[str | None] = os.getenv("WATSONX_URL")
PROJECT_ID:     Final[str | None] = os.getenv("PROJECT_ID")

if not all([WATSONX_APIKEY, WATSONX_URL, PROJECT_ID]):
    missing = [k for k, v in {
        "WATSONX_APIKEY": WATSONX_APIKEY,
        "WATSONX_URL":    WATSONX_URL,
        "PROJECT_ID":     PROJECT_ID,
    }.items() if not v]
    raise SystemExit(
        f"Missing required environment variables: {', '.join(missing)}. "
        "Create a .env file or export them before running."
    )

# --------------------------------------------------------------------------- #
# Pydantic models
# --------------------------------------------------------------------------- #
class ToolArgs(BaseModel):
    prompt: str


class ToolRequest(BaseModel):
    tool: str
    args: ToolArgs


class ToolResponse(BaseModel):
    result: str


# --------------------------------------------------------------------------- #
# Model initialisation (lazy singleton)
# --------------------------------------------------------------------------- #
@lru_cache
def get_model() -> Optional[ModelInference]:
    """
    Cache a single ModelInference client. Return None if initialisation fails
    so later requests can respond quickly with 503.
    """
    logger.info("Initialising Watsonx.ai model …")

    # --- Watsonx.ai Model Initialisation ---
    credentials = Credentials(url=WATSONX_URL, api_key=WATSONX_APIKEY)
    decoding="sample"
    if decoding == "sample":

        parameters = {
            GenParams.DECODING_METHOD: "sample",
            GenParams.MAX_NEW_TOKENS: 512,
            GenParams.MIN_NEW_TOKENS: 50,
            GenParams.TEMPERATURE: 0.7,
            GenParams.TOP_P: 0.9,
            GenParams.REPETITION_PENALTY: 1.2,
            GenParams.STOP_SEQUENCES: ["\n\n", "===", "---"],
        }
    else:
            parameters = {                      
        GenParams.DECODING_METHOD:    "greedy",
        GenParams.MAX_NEW_TOKENS:     512,
        GenParams.MIN_NEW_TOKENS:     1,
        GenParams.REPETITION_PENALTY: 1.1,
        GenParams.STOP_SEQUENCES:     ["\n\n", "===", "---"],
    }


    try:
        model = ModelInference(
            model_id="ibm/granite-13b-instruct-v2",
            params=parameters,
            credentials=credentials,
            project_id=PROJECT_ID,
        )
        logger.info("Watsonx.ai model ready.")
        return model
    except Exception as exc:
        logger.exception("Watsonx.ai initialisation failed", exc_info=True)
        return None  # type: ignore[return-value]


# --------------------------------------------------------------------------- #
# FastAPI application
# --------------------------------------------------------------------------- #
app = FastAPI(
    title="Watsonx Chat Agent",
    description="MCP-compatible microservice backed by IBM Watsonx.ai",
    version="1.0.0",
)


@app.get("/", summary="Health-check")
async def health() -> dict[str, str]:
    return {"status": "ok", "agent": "watsonx-agent"}


@app.post("/http", response_model=ToolResponse, summary="Invoke tool")
async def call_tool(
    payload: ToolRequest,
    model: Optional[ModelInference] = Depends(get_model),
) -> ToolResponse:
    """Only the 'chat' tool is supported."""
    if payload.tool.lower() != "chat":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Tool '{payload.tool}' not found.",
        )

    if model is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Watsonx model unavailable",
        )

    prompt_preview = payload.args.prompt.replace("\n", " ")[:80]
    logger.info("Prompt: %s%s", prompt_preview, "…" if len(prompt_preview) == 80 else "")

    try:
        result = model.generate_text(prompt=payload.args.prompt)
        return ToolResponse(result=result)
    except Exception as exc:  # pragma: no cover
        logger.exception("Watsonx.ai error")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Error communicating with Watsonx.ai",
        ) from exc


# --------------------------------------------------------------------------- #
# Entry-point
# --------------------------------------------------------------------------- #
if __name__ == "__main__":  # pragma: no cover
    import uvicorn

    logger.info("Starting Watsonx Chat Agent at http://0.0.0.0:8082")
    uvicorn.run("main:app", host="0.0.0.0", port=8082, log_level="info")

```

### `Makefile`

```makefile
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
```

### `Dockerfile`

```dockerfile
# Dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY main.py .

EXPOSE 8082

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8082"]
```