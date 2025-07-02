import anyio
from mcp.client.sse import sse_client
from mcp.client.session import ClientSession

async def evaluate_tools():
    # 1) Connect to your demo server’s SSE endpoint
    url = "http://127.0.0.1:6278/sse"
    async with sse_client(url) as (read_stream, write_stream):
        # 2) Establish an MCP session
        async with ClientSession(read_stream, write_stream) as session:
            # 3) Do the handshake
            await session.initialize()

            # 4) List tools
            page = await session.list_tools()
            # The SDK returns a page object with .tools
            tools = getattr(page, "tools", []) or page.get("tools", [])
            print("🔍 Available tools:")
            for tool in tools:
                desc = getattr(tool, "description", "")
                print(f" • {tool.name} — {desc}")

            # 5) Evaluate each tool
            for tool in tools:
                name = tool.name
                params = {} if name == "ping" else {"prompt": "Hello from inference.py"}
                try:
                    # FIX: Use 'session.call_tool' instead of 'session.request'.
                    # The 'call_tool' method returns a result object, and printing it
                    # yields the detailed format you want.
                    result = await session.call_tool(name, params)
                    print(f"\n📨 {name}({params}) → {result}")
                except Exception as e:
                    print(f"\n❌ {name} failed:", e)

if __name__ == "__main__":
    anyio.run(evaluate_tools)