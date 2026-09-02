#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "→ wsl-chrome setup — WSL + Windows Brave CDP + isolated Playwright MCP"
echo "  Node: $(node -v 2>&1)  npm: $(npm -v 2>&1)  opencode: $(opencode --version 2>&1 | head -n1)"

# 1) Node check
if ! node -e "process.exit(parseInt(process.versions.node.split('.')[0],10) < 18 ? 1:0)"; then
  echo "✗ Node 18+ required (have $(node -v)). Install via nvm or apt."
  exit 1
fi

# 2) deps
if [[ ! -d node_modules ]]; then
  echo "→ npm install"
  npm install
else
  echo "→ node_modules present — skipping npm install (run npm install if needed)"
fi

# 3) @playwright/mcp probe
echo "→ probing @playwright/mcp@latest"
npx -y @playwright/mcp@latest --version 2>&1 | head -n1 || echo " (probe failed — will be fetched on first MCP spawn)"

# 4) secrets
if [[ ! -f .secrets.env ]]; then
  echo "→ creating .secrets.env from .secrets.env.example"
  cp .secrets.env.example .secrets.env
  chmod 600 .secrets.env
  echo "  ✏️  Edit .secrets.env — set AUTH_URL/USERNAME/PASSWORD/SUCCESS_PATH"
else
  echo "→ .secrets.env already exists"
  chmod 600 .secrets.env || true
fi

# 5) storage-state
mkdir -p config
if [[ ! -f config/storage-state.json ]]; then
  echo "→ creating empty config/storage-state.json"
  cp config/storage-state.example.json config/storage-state.json
fi

# 6) ensure scripts executable
chmod +x scripts/*.sh 2>/dev/null || true

# 7) validate opencode.jsonc
echo "→ validating opencode.jsonc"
if command -v opencode >/dev/null 2>&1; then
  opencode mcp list 2>&1 | head -n 30 || echo "  (opencode mcp list — may need CDP up first, that's ok)"
else
  echo "  opencode not on PATH — install via https://opencode.ai/docs"
fi

# 8) CDP check (non-fatal)
bash scripts/check-cdp.sh 2>&1 || echo "  CDP not up yet — launch Brave: bash scripts/launch-brave-debug.sh  or double-click scripts/launch-brave-debug.cmd on Windows"

echo ""
echo "✓ setup done"
echo "  Next:"
echo "    1) bash scripts/launch-brave-debug.sh   # or double-click .cmd on Windows"
echo "    2) bash scripts/check-cdp.sh"
echo "    3) opencode                              # then: use playwright to navigate to \$AUTH_URL"
echo "    4) bash scripts/smoke-test.sh  |  bash scripts/test-auth.sh"
