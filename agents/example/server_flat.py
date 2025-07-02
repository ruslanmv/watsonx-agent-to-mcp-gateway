# server_flat.py  – lenient version
from mcp.server.fastmcp import FastMCP
from typing import Union

mcp = FastMCP(name="watsonx-demo-agent", port=6279)

@mcp.tool(description="Chat with IBM watsonx.ai")
async def watsonx_chat(prompt: Union[str, int]) -> dict:
    """Accepts either str or int so the UI's default 0 is valid."""
    return {"reply": f"[watsonx-stub] you said: {prompt}"}

if __name__ == "__main__":
    mcp.run(transport="sse")
