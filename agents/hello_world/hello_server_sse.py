# agents/hello_world/hello_server.py
import logging
from typing import Union

from mcp.server.fastmcp import FastMCP

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)

PORT = 6274                        # same port you’ll enter in “Add Gateway”
mcp  = FastMCP(name="hello-world-agent", port=PORT)

# ─── Tool: echo ────────────────────────────────────────────────────────────
@mcp.tool(description="Echo back whatever you send (accepts str or int)")
async def echo(text: Union[str, int]) -> dict:
    """
    • Accepts either str or int so the Admin UI’s default `0` validates.
    • Returns a dict with a `reply` key; the Gateway renders that nicely.
    """
    logging.info("echo(%r)", text)
    return {"reply": str(text)}

# ─── Run over SSE ──────────────────────────────────────────────────────────
if __name__ == "__main__":
    logging.info("🚀 Serving Hello World agent on http://127.0.0.1:%d/sse", PORT)
    mcp.run(transport="sse")        # Gateway Transport Type = “SSE”
