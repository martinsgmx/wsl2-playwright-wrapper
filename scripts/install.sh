#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# playwright-wrapper-mcp — one-command installer for OpenCode (WSL2-only)
#
# What it does:
#   1. Clones (or updates) this repo into ~/.opencode/wsl-chrome  (GLOBAL, so it
#      is NOT inside your project's git tree — nothing to gitignore in the project).
#   2. Installs the Playwright dependency (npm install) so capture-storage-state
#      and the MCP wrapper work.
#   3. Auto-writes ./opencode.jsonc in the CURRENT directory to point OpenCode's
#      MCP at the wrapper's absolute path (confirms before overwriting an existing
#      opencode.jsonc).
#
# Usage (from a WSL2 shell, inside any project you want to give browser access):
#   curl -fsSL https://raw.githubusercontent.com/martinsgmx/wsl2-playwright-wrapper/main/install.sh | bash
#   # or, once cloned:  bash ~/.opencode/wsl-chrome/scripts/install.sh
#
# After: bash ~/.opencode/wsl-chrome/scripts/launch-brave-debug.sh && opencode
# =============================================================================

REPO_URL="${WSL_PW_REPO_URL:-https://github.com/martinsgmx/wsl2-playwright-wrapper.git}"
INSTALL_DIR="${WSL_PW_INSTALL_DIR:-$HOME/.opencode/wsl-chrome}"
PROJECT_JSONC="${OPENCODE_JSONC:-./opencode.jsonc}"

echo "== playwright-wrapper-mcp installer =="
echo "  repo  : $REPO_URL"
echo "  target: $INSTALL_DIR"
echo "  node  : $(node -v 2>&1)  npm: $(npm -v 2>&1)  opencode: $(opencode --version 2>&1 | head -n1)"

# --- 0) prereqs --------------------------------------------------------------
if ! command -v git >/dev/null 2>&1; then echo "✗ git not installed"; exit 1; fi
if ! node -e "process.exit(parseInt(process.versions.node.split('.')[0],10) < 18 ? 1:0)" 2>/dev/null; then
  echo "✗ Node 18+ required (have $(node -v)). Install via nvm or apt."; exit 1
fi

# --- 1) clone / update -------------------------------------------------------
mkdir -p "$HOME/.opencode"
if [[ -d "$INSTALL_DIR/.git" ]]; then
  echo "→ repo exists, updating..."
  ( cd "$INSTALL_DIR" && git fetch --quiet && git reset --hard --quiet origin/main 2>/dev/null || git pull --quiet )
else
  echo "→ cloning into $INSTALL_DIR ..."
  git clone --quiet "$REPO_URL" "$INSTALL_DIR"
fi

# --- 2) install deps (playwright) -------------------------------------------
echo "→ npm install (playwright) in $INSTALL_DIR"
( cd "$INSTALL_DIR" && npm install --no-audit --no-fund )
chmod +x "$INSTALL_DIR"/scripts/*.sh 2>/dev/null || true

# --- 3) wire the project's opencode.jsonc ------------------------------------
WRAPPER="$INSTALL_DIR/scripts/mcp-wrapper.sh"
mkdir -p "$(dirname "$PROJECT_JSONC")"

if [[ -f "$PROJECT_JSONC" ]]; then
  if grep -q "mcp-wrapper.sh" "$PROJECT_JSONC" 2>/dev/null; then
    echo "→ $PROJECT_JSONC already points at the wrapper (leaving as-is)."
  else
    read -r -p "→ $PROJECT_JSONC exists without the wrapper. Overwrite with wrapper config? [y/N] " yn
    if [[ "${yn:-N}" != [yY] ]]; then
      echo "  Skipped writing $PROJECT_JSONC. You can add the entry manually (see docs/configuration.md)."
      cd "$INSTALL_DIR" && bash scripts/check-cdp.sh 2>&1 || echo "  (launch a browser first)"
      echo "✓ installed to $INSTALL_DIR. Manually wire opencode.jsonc, then: opencode"
      exit 0
    fi
  fi
fi

cat > "$PROJECT_JSONC" <<JSONC
{
  "\$schema": "https://opencode.ai/config.json",
  "mcp": {
    "playwright": {
      "type": "local",
      "command": ["bash", "${WRAPPER}"],
      "enabled": true,
      "timeout": 10000
    }
  }
}
JSONC
echo "→ wrote $PROJECT_JSONC (wrapper at $WRAPPER)"

# --- 4) smoke: CDP + secrets (optional) --------------------------------------
if [[ ! -f "$INSTALL_DIR/.secrets.env" ]]; then
  cp "$INSTALL_DIR/.secrets.env.example" "$INSTALL_DIR/.secrets.env"
  chmod 600 "$INSTALL_DIR/.secrets.env"
  echo "→ created $INSTALL_DIR/.secrets.env — edit it to set AUTH_URL/USERNAME/PASSWORD/SUCCESS_PATH"
fi

( cd "$INSTALL_DIR" && bash scripts/check-cdp.sh 2>&1 || \
  echo "  CDP not up yet — launch a browser: bash $INSTALL_DIR/scripts/launch-brave-debug.sh" )

echo ""
echo "✓ done."
echo "  Next:"
echo "    1) bash $INSTALL_DIR/scripts/launch-brave-debug.sh   # BROWSER=auto|chrome|edge"
echo "    2) opencode"
echo "    3) in the TUI:   use playwright to navigate to https://example.com/ and report console errors"
echo ""
echo "  Repo lives at $INSTALL_DIR (global, not tracked by this project)."
