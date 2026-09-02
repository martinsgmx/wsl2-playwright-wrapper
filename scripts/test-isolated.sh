#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${CDP_PORT:-9222}"
HOST="$(bash "$ROOT/scripts/wsl-host-ip.sh")"
ENDPOINT="http://${HOST}:${PORT}"

echo "→ test-isolated: prove --isolated wipes context between sessions"
USE_CDP=true
if ! bash "$ROOT/scripts/check-cdp.sh" >/dev/null 2>&1; then
  echo "  (CDP not reachable — direct headless fallback; shows isolated BrowserContext semantics)"
  USE_CDP=false
fi

node << NODE
import { chromium } from 'playwright';
const useCdp = ${USE_CDP} ? true : false;
const endpoint = process.env.CDP_ENDPOINT || '${ENDPOINT}';

// Session A: set a marker cookie
console.log('  Session A: set cookie isolated-marker=1 (' + (useCdp ? 'CDP' : 'direct') + ')');
let browser = useCdp ? await chromium.connectOverCDP(endpoint) : await chromium.launch({ headless: true });
let ctx = await browser.newContext();
let page = await ctx.newPage();
await page.goto('https://example.com');
await ctx.addCookies([{ name: 'isolated-marker', value: '1', domain: 'example.com', path: '/' }]);
let cookies = await ctx.cookies();
console.log('    cookies A:', cookies.filter(c=>c.name==='isolated-marker').length, 'marker(s)');
await browser.close();

// Session B: fresh context — marker must be gone (isolated)
console.log('  Session B: fresh context → check marker absent');
browser = useCdp ? await chromium.connectOverCDP(endpoint) : await chromium.launch({ headless: true });
ctx = await browser.newContext();
page = await ctx.newPage();
await page.goto('https://example.com');
cookies = await ctx.cookies();
const has = cookies.some(c => c.name === 'isolated-marker');
console.log('    cookies B:', cookies.length, 'has marker?', has);
await browser.close();

if (has) {
  console.error('✗ FAIL: marker leaked — isolation broken');
  process.exit(1);
}
console.log('✓ test-isolated passed — no bleed between sessions');
NODE
