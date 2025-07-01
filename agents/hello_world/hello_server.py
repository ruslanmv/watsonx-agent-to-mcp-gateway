# agents/hello_world/hello_server.py

import logging
from mcp.server.fastmcp import FastMCP

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

# 1) Define a FastMCP server
mcp = FastMCP("Hello World Agent")

# 2) Expose an `echo` tool that simply returns whatever it gets
@mcp.tool()
def echo(text: str) -> str:
    logging.info("echo() called with %r", text)
    return text

# 3) Run on STDIO
if __name__ == "__main__":
    logging.info("Starting Hello World MCP server on STDIO…")
    mcp.run()