    curl -X POST \
      -H "Content-Type: application/json" \
      -d '{"tool": "chat", "args": {"prompt": "Write a short poem about AI."}}' \
      http://localhost:8082/http