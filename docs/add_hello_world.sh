curl -X POST http://localhost:4444/servers \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
        "name": "hello-world-agent",
        "description": "A minimal STDIO agent that echoes back input via the `echo` tool",
        "associatedTools": ["echo"],
        "associatedResources": [],
        "associatedPrompts": []
      }'