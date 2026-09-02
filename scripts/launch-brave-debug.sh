#!/usr/bin/env bash
set -euo pipefail
# WSL shim that launches Windows Chrome/Brave/Edge with CDP. Handles appendWindowsPath=false and UNC issues.
# Chromium-family only. Env: CDP_PORT, CDP_ADDR, BROWSER (auto|brave|chrome|edge), CDP_USER_DATA_DIR.
# IMPORTANT: always use a dedicated --user-data-dir. If we launched on the browser's real
# default profile while that browser is already open, the new instance just focuses the
# existing one and IGNORES --remote-debugging-port (=> CDP never binds). So each CDP launch
# uses a stable, named "Playwright" profile under %LOCALAPPDATA% (per browser) so the port
# always binds and never collides with your everyday browser profile.
PORT="${CDP_PORT:-9222}"
BROWSER="${BROWSER:-auto}"
ADDR="127.0.0.1"
if grep -q "networkingMode=mirrored" /etc/wsl.conf 2>/dev/null; then
  ADDR="127.0.0.1"
else
  ADDR="${CDP_ADDR:-127.0.0.1}"
fi

# Named "Playwright" profile per browser so launches don't collide with real profiles.
# Override entirely with CDP_USER_DATA_DIR (Windows or WSL path you supply).
USER_DATA_DIR="${CDP_USER_DATA_DIR:-${USER_DATA_DIR:-}}"

POW="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
CMD="/mnt/c/Windows/System32/cmd.exe"
PS1_WSL="$(dirname "$0")/launch-brave-debug.ps1"
PS1_WSL_ABS="$(realpath "$PS1_WSL" 2>/dev/null || echo "$PS1_WSL")"

# Resolve Windows LOCALAPPDATA (global) for the stable Playwright profile dir
LOCAL_APPDATA="$("$POW" -Command "echo \$env:LOCALAPPDATA" 2>/dev/null | tr -d '\r' | head -n1 || echo "")"
if [[ -z "$LOCAL_APPDATA" ]]; then
  LOCAL_APPDATA="C:\\Users\\Denim\\AppData\\Local"
fi
# Normalize browser choice into a safe folder token (auto -> brave by default)
BROWSER_SAFE="${BROWSER}"
if [[ "$BROWSER_SAFE" == "auto" ]]; then BROWSER_SAFE="brave"; fi
PROFILE_WIN="${USER_DATA_DIR:-${LOCAL_APPDATA}\\Playwright\\${BROWSER_SAFE}}"

echo "> Launching Windows browser with CDP port $PORT (addr $ADDR), BROWSER=$BROWSER ..."

# Helper: get Windows TEMP dir and copy PS1 there to avoid UNC execution issues
launch_via_powershell() {
  local win_ps1="$1"
  # Get Windows TEMP via powershell if possible
  local win_temp
  win_temp="$("$POW" -Command "echo \$env:TEMP" 2>/dev/null | tr -d '\r' | head -n1 || echo "")"
  if [[ -z "$win_temp" ]]; then
    win_temp="C:\\Users\\Denim\\AppData\\Local\\Temp"
  fi
  # Convert to WSL path for copy
  local wsl_temp
  if command -v wslpath >/dev/null 2>&1; then
    wsl_temp="$(wslpath -u "$win_temp" 2>/dev/null || echo "/mnt/c/Users/Denim/AppData/Local/Temp")"
  else
    wsl_temp="/mnt/c/Users/Denim/AppData/Local/Temp"
  fi
  mkdir -p "$wsl_temp" 2>/dev/null || true
  local tmp_ps1="$wsl_temp/wsl-chrome-launch-brave-debug.ps1"
  cp -f "$PS1_WSL_ABS" "$tmp_ps1" 2>/dev/null || cp -f "$PS1_WSL" "$tmp_ps1"
  local win_tmp_ps1
  if command -v wslpath >/dev/null 2>&1; then
    win_tmp_ps1="$(wslpath -w "$tmp_ps1" 2>/dev/null || echo "$win_temp\\wsl-chrome-launch-brave-debug.ps1")"
  else
    win_tmp_ps1="$win_temp\\wsl-chrome-launch-brave-debug.ps1"
  fi
  echo "> Running PowerShell from $win_tmp_ps1"

  local extra_args=()
  if [[ "$BROWSER" != "auto" ]]; then
    extra_args+=("-Browser" "$BROWSER")
  fi
  extra_args+=("-UserDataDir" "$PROFILE_WIN")
  "$POW" -NoProfile -ExecutionPolicy Bypass -File "$win_tmp_ps1" -Port "$PORT" "${extra_args[@]}"
}

POW_OK=false
if [[ -x "$POW" ]]; then
  if launch_via_powershell "$PS1_WSL_ABS"; then
    POW_OK=true
  else
    echo "> PowerShell returned non-zero - checking if CDP is already up before fallback..."
    if curl -s --max-time 2 "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1 || curl -s --max-time 2 "http://localhost:${PORT}/json/version" >/dev/null 2>&1; then
      echo "> CDP already reachable - skipping cmd fallback"
      POW_OK=true
    else
      echo "> PowerShell launch failed, trying cmd.exe fallback..."
      BRAVE_WIN="C:\\Program Files\\BraveSoftware\\Brave-Browser\\Application\\brave.exe"
      BRAVE_WSL="/mnt/c/Program Files/BraveSoftware/Brave-Browser/Application/brave.exe"
      CHROME_WIN="C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"
      CHROME_WSL="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
      EDGE_WIN="C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"
      EDGE_WSL="/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
      chosen_win="" chosen_wsl=""
      case "$BROWSER" in
        chrome) chosen_win="$CHROME_WIN"; chosen_wsl="$CHROME_WSL";;
        edge)   chosen_win="$EDGE_WIN"; chosen_wsl="$EDGE_WSL";;
        brave|auto|*) chosen_win="$BRAVE_WIN"; chosen_wsl="$BRAVE_WSL";;
      esac
      if [[ -n "$chosen_wsl" ]] && [[ -f "$chosen_wsl" ]]; then
        "$CMD" /c "cd /d C:\\ && start \"\" \"$chosen_win\" --remote-debugging-port=$PORT --remote-debugging-address=$ADDR --user-data-dir=\"$PROFILE_WIN\" --no-first-run --no-default-browser-check" || true
      else
        echo "Browser '$BROWSER' not found at expected path: $chosen_wsl"
        POW_OK=false
      fi
    fi
  fi
elif [[ -x "$CMD" ]]; then
  BRAVE_WIN="C:\\Program Files\\BraveSoftware\\Brave-Browser\\Application\\brave.exe"
  BRAVE_WSL="/mnt/c/Program Files/BraveSoftware/Brave-Browser/Application/brave.exe"
  CHROME_WIN="C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"
  CHROME_WSL="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
  EDGE_WIN="C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"
  EDGE_WSL="/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
  chosen_win="" chosen_wsl=""
  case "$BROWSER" in
    chrome) chosen_win="$CHROME_WIN"; chosen_wsl="$CHROME_WSL";;
    edge)   chosen_win="$EDGE_WIN"; chosen_wsl="$EDGE_WSL";;
    brave|auto|*) chosen_win="$BRAVE_WIN"; chosen_wsl="$BRAVE_WSL";;
  esac
  "$CMD" /c "cd /d C:\\ && start \"\" \"$chosen_win\" --remote-debugging-port=$PORT --remote-debugging-address=$ADDR --user-data-dir=\"$PROFILE_WIN\" --no-first-run --no-default-browser-check" || true
else
  echo "Cannot find powershell.exe nor cmd.exe at expected /mnt/c/Windows/... — is /mnt/c mounted? ls /mnt/c"
  exit 1
fi

# Poll CDP from WSL
echo "> Polling CDP at http://localhost:${PORT}/json/version ..."
for i in {1..20}; do
  if curl -s --max-time 2 "http://localhost:${PORT}/json/version" >/dev/null 2>&1; then
    echo "OK CDP ready"
    bash "$(dirname "$0")/check-cdp.sh" || true
    exit 0
  fi
  sleep 0.5
done
echo "CDP not responding after 10s — try double-clicking scripts/launch-brave-debug.cmd on Windows side, then run bash scripts/check-cdp.sh"
exit 1
