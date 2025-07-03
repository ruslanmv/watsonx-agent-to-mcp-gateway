#!/usr/bin/env python3
"""
frontend.py – FastAPI micro-frontend for MCP Gateway
(Logging-rich version: prints every step, easy to debug.)
"""
import os, sys, subprocess, logging
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Literal, Dict, Any

import httpx, uvicorn
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel

# ─────────────────── config & logging ────────────────────
load_dotenv()
GATEWAY_RPC = os.getenv("GATEWAY_RPC", "http://localhost:4444/rpc")
BASIC_AUTH_USER = os.getenv("BASIC_AUTH_USER", "admin")
BASIC_AUTH_PASS = os.getenv("BASIC_AUTH_PASS", "adminpw")
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "my-test-key")

logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger("frontend")
# Suppress verbose logs from http libraries for cleaner output
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)


FRONTEND_DIR = Path(__file__).parent / "frontend"
INDEX_HTML = FRONTEND_DIR / "index.html"

# ─────────────────── pydantic models ─────────────────────
class ChatArgs(BaseModel):
    prompt: str

class ChatRequest(BaseModel):
    tool: str
    args: ChatArgs

class ChatResponse(BaseModel):
    result: str

# ─────────────────── jwt helper (for debugging) ──────────
def mint_jwt() -> str:
    """
    Calls the mcpgateway utility to create a short-lived JWT.
    This is inefficient for production but simple for a demo.
    """
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
            raise ValueError("Minted JWT token is empty.")
        return token
    except subprocess.CalledProcessError as e:
        logger.error("Failed to mint JWT. Subprocess error: %s", e.stderr)
        raise

# ─────────────────── FastAPI app & lifespan ───────────────
# FIX: Replaced deprecated on_event with the modern lifespan context manager.
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Code to run on startup
    logger.info("Starting chatbot server on http://localhost:8000")
    logger.info("Ensure your MCP Gateway is running and accessible at %s", GATEWAY_RPC)
    if not INDEX_HTML.exists():
        logger.warning("Frontend file not found at %s. The UI will not be available.", INDEX_HTML)
    yield
    # Code to run on shutdown (if any)
    logger.info("Chatbot server shutting down.")

app = FastAPI(title="Chatbot Frontend", lifespan=lifespan)

@app.get("/", include_in_schema=False)
async def root():
    if INDEX_HTML.exists():
        return FileResponse(INDEX_HTML)
    return {"detail": "index.html not found in ./frontend/. Please create it."}

@app.post("/call", response_model=ChatResponse)
async def call_tool(req: ChatRequest):
    """Relay the user prompt to the MCP Gateway and return the reply text."""
    tool = req.tool.replace("/", "-")
    prompt = req.args.prompt
    logger.info("🎯 Tool: %s  |  💬 Prompt: %s", tool, prompt)

    param_key: Literal["query", "text"] = "query" if "chat" in tool else "text"
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": tool,
        "params": {param_key: prompt},
    }
    logger.debug("JSON-RPC payload: %s", payload)

    try:
        jwt_token = mint_jwt()
        logger.debug("Minted JWT successfully.")
    except Exception:
        raise HTTPException(status_code=500, detail="Failed to mint JWT token to authenticate with the gateway.")

    # FIX: The gateway requires a Bearer token. Sending Basic Auth via the `auth`
    # parameter was overwriting the 'Authorization' header. We now only send the
    # required Bearer token header.
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {jwt_token}"
    }
    logger.debug("POST %s  headers=%s", GATEWAY_RPC, headers)

    async with httpx.AsyncClient(timeout=60) as client:
        try:
            # FIX: Removed the `auth` parameter to prevent overwriting the header.
            resp = await client.post(GATEWAY_RPC, json=payload, headers=headers)
            logger.info("Gateway responded %d %s", resp.status_code, resp.reason_phrase)
            resp.raise_for_status()
        except httpx.HTTPStatusError as exc:
            logger.error("Body on error: %s", exc.response.text)
            raise HTTPException(status_code=exc.response.status_code,
                                detail=f"Error from gateway: {exc.response.text}")
        except Exception as exc:
            logger.exception("Connection to Gateway failed")
            raise HTTPException(status_code=502, detail=f"Could not connect to gateway: {str(exc)}")

    data = resp.json()
    logger.debug("Raw Gateway JSON: %s", data)

    text = ""
    if "result" in data and isinstance(data["result"], dict):
        result = data["result"]
        if "reply" in result:
            text = result["reply"]
        elif "content" in result and isinstance(result["content"], list) and result["content"]:
            text = result["content"][0].get("text")
    elif "content" in data and isinstance(data["content"], list) and data["content"]:
         text = data["content"][0].get("text")

    if not text:
        text = "Could not extract reply text from gateway response."
        logger.warning("Could not find reply text in response: %s", data)

    logger.info("💡 Reply extracted: %s", text)
    return ChatResponse(result=text)

# ─────────────────── entrypoint ──────────────────────────
if __name__ == "__main__":
    uvicorn.run("frontend:app", host="0.0.0.0", port=8000, reload=True)
