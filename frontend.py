#!/usr/bin/env python3
"""
frontend.py – FastAPI micro-frontend for MCP Gateway
"""
import os
import sys
import subprocess
import logging
import re
from pathlib import Path
from typing import Literal
from contextlib import asynccontextmanager     # FIX: use contextlib for lifespan

import httpx
import uvicorn
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles # 1. IMPORT THIS


from pydantic import BaseModel

# ─────────────────── config & logging ────────────────────
load_dotenv()
GATEWAY_RPC     = os.getenv("GATEWAY_RPC",     "http://localhost:4444/rpc")
BASIC_AUTH_USER = os.getenv("BASIC_AUTH_USER", "admin")
BASIC_AUTH_PASS = (
    os.getenv("BASIC_AUTH_PASS")
    or os.getenv("BASIC_AUTH_PASSWORD")
    or "adminpw"
)
JWT_SECRET_KEY  = os.getenv("JWT_SECRET_KEY",  "my-test-key")

logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger("frontend")
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)

FRONTEND_DIR = Path(__file__).parent / "frontend"
INDEX_HTML   = FRONTEND_DIR / "index.html"


# ─────────────────── pydantic models ─────────────────────
class ChatArgs(BaseModel):
    prompt: str

class ChatRequest(BaseModel):
    tool: str
    args: ChatArgs

class ChatResponse(BaseModel):
    result: str

# ─────────────────── jwt helper ──────────────────────────
def mint_jwt() -> str:
    cmd = [
        sys.executable, "-m", "mcpgateway.utils.create_jwt_token",
        "--username", BASIC_AUTH_USER,
        "--secret",   JWT_SECRET_KEY,
        "--exp",      "60",
    ]
    logger.debug("Minting JWT via subprocess: %s", " ".join(cmd))
    token = subprocess.check_output(cmd, text=True, stderr=subprocess.PIPE).strip()
    if not token:
        raise RuntimeError("Minted JWT is empty")
    return token

# ─────────────────── lifespan handler ────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting chatbot server on http://localhost:8000")
    logger.info("Ensure MCP Gateway is reachable at %s", GATEWAY_RPC)
    if not INDEX_HTML.exists():
        logger.warning(
            "UI file %s not found – only /call endpoint will work.", INDEX_HTML
        )
    yield
    # (no shutdown actions needed)

app = FastAPI(title="Chatbot Frontend", lifespan=lifespan)

STATIC_DIR = os.path.join(FRONTEND_DIR, "static")
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")



@app.get("/", include_in_schema=False)
async def root():
    return FileResponse(INDEX_HTML) if INDEX_HTML.exists() else {
        "detail": "index.html missing in ./frontend/"
    }

@app.post("/call", response_model=ChatResponse)
async def call_tool(req: ChatRequest):
    tool   = req.tool.replace("/", "-")
    prompt = req.args.prompt
    logger.info("🎯 %s  |  💬 %s", tool, prompt)

    payload = {
        "jsonrpc": "2.0",
        "id":      1,
        "method":  tool,
        "params":  {"query" if "chat" in tool else "text": prompt},
    }

    try:
        jwt_token = mint_jwt()
    except Exception:
        raise HTTPException(status_code=500, detail="Could not mint JWT.")

    headers = {
        "Content-Type":  "application/json",
        "Authorization": f"Bearer {jwt_token}",
    }

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
    text = (
        data.get("result", {}).get("reply")
        or (data.get("result", {}).get("content") or [{}])[0].get("text")
        or (data.get("content") or [{}])[0].get("text")
        or ""
    )

    # Strip the gateway’s stray “?” token
    text = re.sub(r'^\s*\?\s*\n*', '', text, count=1).strip()

    if not text:
        text = "Could not extract reply text from gateway response."
        logger.warning("No reply text in response: %s", data)

    logger.info("💡 Reply: %s", text)
    return ChatResponse(result=text)

# ─────────────────── entrypoint ──────────────────────────
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
