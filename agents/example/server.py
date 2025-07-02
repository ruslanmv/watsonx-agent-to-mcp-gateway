"""
watsonx-demo MCP server – Hello World

Tools exposed
─────────────
• ping          → {"reply": "pong"}
• watsonx-chat  → {"reply": PROMPT.upper()}

Run
───
pip install "mcp[fastapi]" uvicorn
python server.py            # port 6278 by default
"""

import os, time, logging
from mcp.server.fastmcp import FastMCP

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
log = logging.getLogger("watsonx-demo")

PORT = int(os.getenv("PORT", 6278))

# 1 ────────────────────────────────────────────────────────────────
mcp = FastMCP(name="watsonx-demo-agent", version="0.1.0", port=PORT)

# 2 ────────────────────────────────────────────────────────────────
@mcp.tool(description="Responds with pong")
async def ping() -> dict:
    log.info("ping() called")
    return {"reply": "pong"}

@mcp.tool(description="Chat with IBM watsonx.ai (dummy)")
async def watsonx_chat(prompt: str) -> dict:
    log.info("watsonx_chat(%s)", prompt)
    time.sleep(0.2)                       # simulate latency
    return {"reply": prompt.upper()}

# 3 ────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    log.info("🚀 listening on http://0.0.0.0:%d/sse", PORT)
    mcp.run(transport="sse")              # SSE endpoint is /sse
