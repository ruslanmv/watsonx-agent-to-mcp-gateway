# client.py

import anyio
from mcp.client.sse import sse_client
from mcp.client.session import ClientSession


async def main():
    # 1) Open the SSE transport
    async with sse_client("http://127.0.0.1:6278/sse") as (read_stream, write_stream):
        # 2) Start the MCP session
        async with ClientSession(read_stream, write_stream) as session:
            # 3) Do the handshake
            await session.initialize()

            # 4) Fetch the first page of tools
            tools_page = await session.list_tools()
            
            # Simplified logic to get the list of tools
            tool_items = getattr(tools_page, "tools", []) or tools_page.get("tools", [])

            print("🔍 Available tools:")
            for tool in tool_items:
                desc = getattr(tool, "description", "")
                print(f" • {tool.name} — {desc}")

            # 5) Invoke the `ping` tool
            try:
                # FIX: Use the correct method 'call_tool'
                pong = await session.call_tool("ping", {})
                print("\n📨 ping →", pong)
            except Exception as e:
                print("❌ ping failed:", e)

            # 6) Invoke the `watsonx_chat` tool
            try:
                # FIX: Use the correct method 'call_tool'
                chat = await session.call_tool("watsonx_chat", {"prompt": "hello world"})
                print("📨 watsonx_chat →", chat)
            except Exception as e:
                print("❌ watsonx_chat failed:", e)


if __name__ == "__main__":
    anyio.run(main)