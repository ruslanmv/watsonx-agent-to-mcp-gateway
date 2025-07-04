#!/usr/bin/env python3
"""
ui.py – A dynamic FastAPI frontend for the MCP Gateway with agent selection.
This script is designed to be run from within the 'frontend' directory.
"""
import os
import sys
import subprocess
import logging
import re
from pathlib import Path
from typing import List
from contextlib import asynccontextmanager

import httpx
import uvicorn
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

# ─────────────────── config & logging ────────────────────
# Load .env file from the parent directory (project root)
dotenv_path = Path(__file__).parent.parent / '.env'
load_dotenv(dotenv_path=dotenv_path)

GATEWAY_URL = os.getenv("GATEWAY_URL", "http://localhost:4444")
GATEWAY_RPC = f"{GATEWAY_URL}/rpc"
BASIC_AUTH_USER = os.getenv("BASIC_AUTH_USER", "admin")
# Ensure we check common variations for the password env var
BASIC_AUTH_PASS = (
    os.getenv("BASIC_AUTH_PASS")
    or os.getenv("BASIC_AUTH_PASSWORD")
    or "adminpw"
)
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "my-test-key")

logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger("frontend")
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)

# Since ui.py is inside 'frontend', the paths are relative to this script's location.
FRONTEND_DIR = Path(__file__).parent
INDEX_HTML = FRONTEND_DIR / "main.html"

# ─────────────────── pydantic models ─────────────────────
class ChatArgs(BaseModel):
    prompt: str

class ChatRequest(BaseModel):
    tool: str  # This will be the agent name, e.g., "watsonx-agent"
    args: ChatArgs

class ChatResponse(BaseModel):
    result: str

class Agent(BaseModel):
    name: str

# ─────────────────── jwt helper ──────────────────────────
def mint_jwt() -> str:
    """Calls the mcpgateway utility to create a short-lived JWT."""
    # Correctly locate the python executable for the venv
    venv_python = Path(sys.executable)
    cmd = [
        str(venv_python), "-m", "mcpgateway.utils.create_jwt_token",
        "--username", BASIC_AUTH_USER,
        "--secret", JWT_SECRET_KEY,
        "--exp", "60",
    ]
    logger.debug("Minting JWT via subprocess: %s", " ".join(cmd))
    try:
        token = subprocess.check_output(cmd, text=True, stderr=subprocess.PIPE).strip()
        if not token:
            raise RuntimeError("Minted JWT is empty")
        return token
    except subprocess.CalledProcessError as e:
        logger.error("Failed to mint JWT. Is the correct venv active? Stderr: %s", e.stderr)
        raise RuntimeError(f"Could not execute JWT minting utility: {e.stderr}")
    except FileNotFoundError:
        logger.error("Failed to mint JWT. The Python executable '%s' was not found.", venv_python)
        raise RuntimeError("Could not find the Python executable to mint JWT.")

# ─────────────────── lifespan handler ────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting chatbot server on http://localhost:8000")
    logger.info("Ensure MCP Gateway is reachable at %s", GATEWAY_URL)
    yield
    logger.info("Chatbot server shutting down.")

app = FastAPI(title="Dynamic Chatbot Frontend", lifespan=lifespan)

# Mount static files directory (for images, css, etc.)
STATIC_DIR = FRONTEND_DIR / "static"
if STATIC_DIR.is_dir():
    app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
    logger.info("Serving static files from: %s", STATIC_DIR)

# ─────────────────── API endpoints ───────────────────────
@app.get("/", include_in_schema=False)
async def root():
    """Serves the main index.html file."""
    if not INDEX_HTML.is_file():
        return JSONResponse(
            status_code=404,
            content={"detail": "main.html not found in this directory."}
        )
    return FileResponse(INDEX_HTML)

@app.get("/agents", response_model=List[Agent])
async def get_agents():
    """Fetches the list of active agents (servers) from the MCP Gateway."""
    logger.info("Fetching list of active agents from gateway...")
    try:
        jwt_token = mint_jwt()
    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=str(e))

    headers = {"Authorization": f"Bearer {jwt_token}"}
    
    async with httpx.AsyncClient(timeout=10) as client:
        try:
            resp = await client.get(f"{GATEWAY_URL}/servers", headers=headers)
            resp.raise_for_status()
            servers = resp.json()
            # The agent name is the 'name' field from the /servers endpoint
            active_agents = [Agent(name=s['name']) for s in servers if s.get('isActive')]
            logger.info("Found %d active agents.", len(active_agents))
            return active_agents
        except httpx.RequestError as e:
            logger.error("Could not connect to MCP Gateway at %s. Is it running?", e.request.url)
            raise HTTPException(status_code=502, detail="Could not connect to MCP Gateway.")
        except httpx.HTTPStatusError as e:
            logger.error("Error from gateway: %s", e.response.text)
            raise HTTPException(status_code=e.response.status_code, detail="Error fetching agents from gateway.")

@app.post("/call", response_model=ChatResponse)
async def call_tool(req: ChatRequest):
    """Calls a specific tool on the MCP Gateway."""
    # FIX: The method for the gateway is the agent name plus '/chat'
    agent_name = req.tool
    method = f"{agent_name}/chat"
    prompt = req.args.prompt
    logger.info("🎯 Agent: %s | 💬 Prompt: %s", agent_name, prompt)

    # FIX: The JSON-RPC payload requires the 'method' field to be correctly formatted.
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,  # Use the corrected method name
        "params": {"query": prompt}, # Most chat agents expect 'query'
    }

    try:
        jwt_token = mint_jwt()
    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=str(e))

    headers = {"Authorization": f"Bearer {jwt_token}"}

    async with httpx.AsyncClient(timeout=60) as client:
        try:
            resp = await client.post(GATEWAY_RPC, json=payload, headers=headers)
            resp.raise_for_status()
        except httpx.HTTPStatusError as exc:
            logger.error("Gateway error body: %s", exc.response.text)
            raise HTTPException(
                status_code=exc.response.status_code,
                detail=f"Gateway error: {exc.response.text}"
            )
        except Exception as exc:
            logger.exception("Gateway connection failed")
            raise HTTPException(status_code=502, detail=str(exc))

    data = resp.json()
    
    # Check for RPC error in the response first
    if 'error' in data:
        error_details = data['error']
        logger.warning("Gateway returned an error: %s", error_details)
        # Prettify the error for the frontend
        text = f"Agent Error: {error_details.get('message', 'Unknown Error')}. Details: {error_details.get('data', 'N/A')}"
        return ChatResponse(result=text)

    # Use robust extraction logic from the working example
    text = (
        data.get("result", {}).get("reply")
        or (data.get("result", {}).get("content") or [{}])[0].get("text")
        or (data.get("content") or [{}])[0].get("text")
        or ""
    )
    text = re.sub(r'^\s*\?\s*\n*', '', text, count=1).strip()

    if not text:
        text = "Agent returned an empty response."
        logger.warning("No reply text in response: %s", data)

    logger.info("💡 Reply: %s", text)
    return ChatResponse(result=text)

# ─────────────────── entrypoint ──────────────────────────
if __name__ == "__main__":
    uvicorn.run("ui:app", host="0.0.0.0", port=8000, reload=True)