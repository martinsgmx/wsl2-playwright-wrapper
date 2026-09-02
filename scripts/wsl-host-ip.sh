#!/usr/bin/env bash
set -euo pipefail
# Prints the Windows host as reachable from WSL.
# Mirrored networking → localhost. NAT → gateway IP.

MODE=""
if command -v wslinfo >/dev/null 2>&1; then
  MODE="$(wslinfo --networking-mode 2>/dev/null || true)"
fi
if [[ -z "$MODE" ]] && [[ -f /etc/wsl.conf ]]; then
  if grep -q "networkingMode=mirrored" /etc/wsl.conf 2>/dev/null; then
    MODE="mirrored"
  fi
fi

# Allow explicit override
if [[ -n "${CDP_HOST:-}" ]]; then
  echo "$CDP_HOST"
  exit 0
fi

if [[ "$MODE" == "mirrored" ]] || [[ "$MODE" == "" ]]; then
  # mirrored is default on this box; also fallback if detection fails
  # check if wsl.conf says mirrored — already handled; otherwise assume mirrored
  if grep -q "networkingMode=mirrored" /etc/wsl.conf 2>/dev/null; then
    echo "localhost"
  else
    # If NAT, gateway is the host
    GW="$(ip route show default 2>/dev/null | awk '{print $3}' | head -n1)"
    if [[ -n "$GW" ]]; then
      echo "$GW"
    else
      echo "localhost"
    fi
  fi
else
  GW="$(ip route show default 2>/dev/null | awk '{print $3}' | head -n1)"
  echo "${GW:-localhost}"
fi
