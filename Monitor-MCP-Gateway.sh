# Monitor-MCP-Gateway.sh
#!/usr/bin/env bash
set -euo pipefail

echo "Monitoring MCP Gateway (press Ctrl-C to stop)…"
while true; do
  TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
  PIDS="$(pgrep -f 'mcpgateway --host' || true)"
  if [ -n "$PIDS" ]; then
    echo "$TIMESTAMP | ✅ Running (PID${PIDS// /, PID})"
  else
    echo "$TIMESTAMP | ❌ Not running"
  fi

  # Check if port 4444 is listening
  if ss -tunlp | grep -q ':4444'; then
    echo "$TIMESTAMP | ✅ Listening on port 4444"
  else
    echo "$TIMESTAMP | ❌ Port 4444 not in use"
  fi

  echo "—"
  sleep 5
done
