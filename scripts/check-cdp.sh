#!/usr/bin/env bash
set -euo pipefail
PORT="${CDP_PORT:-9222}"
HOST="$(bash "$(dirname "$0")/wsl-host-ip.sh")"
ENDPOINT="http://${HOST}:${PORT}/json/version"

echo "→ Checking CDP at $ENDPOINT (HOST=$HOST PORT=$PORT)"
echo "  WSL mode: $(wslinfo --networking-mode 2>/dev/null || grep networkingMode /etc/wsl.conf 2>/dev/null || echo 'unknown')"

if ! command -v curl >/dev/null 2>&1; then
  echo "✗ curl not found — install curl"
  exit 1
fi

RESP="$(curl -s --max-time 5 "$ENDPOINT" || true)"
if [[ -z "$RESP" ]]; then
  echo "✗ CDP not reachable at $ENDPOINT"
  echo ""
  echo "  Fix:"
  echo "    1) Launch Brave with CDP:  bash scripts/launch-brave-debug.sh  (WSL)  or double-click scripts/launch-brave-debug.cmd (Windows)"
  echo "    2) Verify:  curl http://localhost:${PORT}/json/version"
  echo "    3) If NAT mode, Brave must use --remote-debugging-address=0.0.0.0 and firewall must allow WSL subnet (see docs/troubleshooting.md)"
  exit 1
fi

echo "$RESP" | python3 -m json.tool 2>/dev/null || echo "$RESP"

WS_URL="$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('webSocketDebuggerUrl',''))" 2>/dev/null || true)"
if [[ -n "$WS_URL" ]]; then
  echo ""
  echo "✓ CDP reachable — webSocketDebuggerUrl: $WS_URL"
else
  echo ""
  echo "✓ CDP reachable (no webSocketDebuggerUrl in response, but endpoint responded)"
fi
