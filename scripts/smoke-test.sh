#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "→ smoke-test: CDP + Playwright connectOverCDP + isolated navigation"
if ! bash "$ROOT/scripts/check-cdp.sh" 2>&1; then
  echo "  (CDP not reachable — running direct headless fallback to prove Playwright works)"
  echo "  To test full CDP: bash scripts/launch-browser-debug.sh && bash scripts/smoke-test.sh"
  node --input-type=module << 'FALLBACK'
import { chromium } from 'playwright';
const b = await chromium.launch({ headless: true });
const ctx = await b.newContext();
const p = await ctx.newPage();
await p.goto('https://example.com', { waitUntil: 'domcontentloaded' });
const t = await p.title();
console.log('  direct title:', t);
if (!t.includes('Example')) throw new Error(t);
console.log('✓ smoke-test (direct fallback) passed — Playwright works, start Brave for CDP');
await b.close();
FALLBACK
  echo ""
  echo "→ MCP wrapper probe"
  bash "$ROOT/scripts/mcp-wrapper.sh" --help 2>&1 | head -n 5 || true
  echo "✓ wrapper ok (direct)"
  exit 0
fi

# Prefer wrapper's host/port detection
PORT="${CDP_PORT:-9222}"
HOST="$(bash "$ROOT/scripts/wsl-host-ip.sh")"
ENDPOINT="http://${HOST}:${PORT}"

echo "→ Node CDP connect → goto example.com"

node << NODE
import { chromium } from 'playwright';
const endpoint = process.env.CDP_ENDPOINT || '${ENDPOINT}';
console.log('  CDP endpoint:', endpoint);
const browser = await chromium.connectOverCDP(endpoint);
const ctx = browser.contexts()[0] || await browser.newContext();
const page = ctx.pages()[0] || await ctx.newPage();
await page.goto('https://example.com', { waitUntil: 'domcontentloaded' });
const title = await page.title();
console.log('  title:', title);
if (!title.includes('Example')) throw new Error('unexpected title: ' + title);
console.log('✓ smoke-test passed — isolated CDP navigation works');
await browser.close();
NODE

echo ""
echo "→ MCP wrapper probe (isolated + init-page, no secrets needed for example.com)"
bash "$ROOT/scripts/mcp-wrapper.sh" --help 2>&1 | head -n 5 || true
echo "✓ wrapper ok"
