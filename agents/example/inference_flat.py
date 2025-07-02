# inference_flat.py

import anyio
from mcp.client.sse import sse_client
from mcp.client.session import ClientSession
import json

async def main():
    """
    Connects to the server_flat.py agent and calls its tool.
    """
    # The server is running on port 6279
    server_url = "http://127.0.0.1:6279/sse"
    print(f"▶️  Connecting to server at {server_url}...")

    try:
        # 1) Open the SSE transport
        async with sse_client(server_url) as (read_stream, write_stream):
            # 2) Start the MCP session
            async with ClientSession(read_stream, write_stream) as session:
                # 3) Do the handshake
                await session.initialize()
                print("✅ Session initialized.")

                # 4) Call the 'watsonx_chat' tool with a string
                prompt_str = "hello from the client"
                print(f"\n📨 Calling watsonx_chat(prompt='{prompt_str}')")
                try:
                    result_str_obj = await session.call_tool("watsonx_chat", {"prompt": prompt_str})
                    # The result content is a JSON string, so we parse it for cleaner output
                    if result_str_obj.content and result_str_obj.content[0].text:
                        reply = json.loads(result_str_obj.content[0].text)
                        print(f"✅ Reply: {reply}")
                    else:
                        print(f"⚠️ Received an empty response.")

                except Exception as e:
                    print(f"❌ Tool call failed: {e}")

                # 5) Call the 'watsonx_chat' tool with an integer
                prompt_int = 42
                print(f"\n📨 Calling watsonx_chat(prompt={prompt_int})")
                try:
                    result_int_obj = await session.call_tool("watsonx_chat", {"prompt": prompt_int})
                    # Parse the JSON string from the result content
                    if result_int_obj.content and result_int_obj.content[0].text:
                        reply = json.loads(result_int_obj.content[0].text)
                        print(f"✅ Reply: {reply}")
                    else:
                        print(f"⚠️ Received an empty response.")

                except Exception as e:
                    print(f"❌ Tool call failed: {e}")

    except anyio.exceptions.ConnectError as e:
        print(f"\n❌ Connection failed. Is server_flat.py running on port 6279?")
        print(f"   Error: {e}")


if __name__ == "__main__":
    anyio.run(main)