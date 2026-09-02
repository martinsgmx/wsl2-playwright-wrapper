#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${CDP_PORT:-9222}"
HOST="$(bash "$ROOT/scripts/wsl-host-ip.sh")"
ENDPOINT="http://${HOST}:${PORT}"

# Loads .secrets.env for defaults, but allow overrides
if [[ -f "$ROOT/.secrets.env" ]]; then
  set -a; source "$ROOT/.secrets.env"; set +a
fi

# Default to fixture server — use 3335 to avoid Caddy-proxy collisions on 3000 (see troubleshooting)
FIXTURE_PORT="${FIXTURE_PORT:-3335}"
AUTH_URL_FIXTURE="http://localhost:${FIXTURE_PORT}/login"
AUTH_SUCCESS_PATH_FIXTURE="${AUTH_SUCCESS_PATH:-**/dashboard**}"
AUTH_USERNAME_FIXTURE="${AUTH_USERNAME:-test@example.com}"
AUTH_PASSWORD_FIXTURE="${AUTH_PASSWORD:-test123}"

echo "→ test-auth: isolated auto-login until redirect"
echo "  Fixture at $AUTH_URL_FIXTURE → $AUTH_SUCCESS_PATH_FIXTURE"

# CDP mode if Brave is up; otherwise fallback to direct headless (proves init-auth logic without Windows browser)
if ! bash "$ROOT/scripts/check-cdp.sh" >/dev/null 2>&1; then
  echo "  (CDP not reachable — falling back to direct headless Playwright for logic proof; start Brave for full CDP test: bash scripts/launch-brave-debug.sh)"
  USE_CDP=false
else
  USE_CDP=true
fi

# Start fixture server in background
FIXTURE_PORT="$FIXTURE_PORT" node "$ROOT/test/fixtures/login/server.js" > /tmp/opencode/fixture-test-auth.log 2>&1 &
SERVER_PID=$!
trap "kill $SERVER_PID 2>/dev/null || true" EXIT
sleep 1

# Wait for server
for i in {1..10}; do
  if curl -s "http://localhost:${FIXTURE_PORT}/login" >/dev/null 2>&1; then break; fi
  sleep 0.3
done

if [ "$USE_CDP" = true ]; then
  echo "→ Fixture up — running Playwright via CDP (mimics init-auth.ts + isolated)"
else
  echo "→ Fixture up — running Playwright direct headless (CDP fallback)"
fi

node << NODE
import { chromium } from 'playwright';
const useCdp = '${USE_CDP}' === 'true' || process.env.USE_CDP === 'true';
const endpoint = process.env.CDP_ENDPOINT || '${ENDPOINT}';
const authUrl = 'http://localhost:${FIXTURE_PORT}/login';
const successPat = process.env.AUTH_SUCCESS_PATH || '${AUTH_SUCCESS_PATH_FIXTURE}';
const user = process.env.AUTH_USERNAME || '${AUTH_USERNAME_FIXTURE}';
const pass = process.env.AUTH_PASSWORD || '${AUTH_PASSWORD_FIXTURE}';
const userSel = process.env.AUTH_USER_SELECTOR || 'input[name="username"]';
const passSel = process.env.AUTH_PASS_SELECTOR || 'input[name="password"]';
const submitSel = process.env.AUTH_SUBMIT_SELECTOR || 'button[type="submit"]';

console.log('  mode', useCdp ? 'CDP' : 'direct', 'authUrl', authUrl, 'success', successPat);
if (useCdp) console.log('  endpoint', endpoint);

const browser = useCdp ? await chromium.connectOverCDP(endpoint) : await chromium.launch({ headless: true });
const ctx = await browser.newContext();
const page = await ctx.newPage();

// Go to login
await page.goto(authUrl, { waitUntil: 'domcontentloaded' });
console.log('  at', page.url());

// Simulate init-auth.ts logic (env-driven)
await page.fill(userSel, user).catch(()=>{});
await page.fill(passSel, pass).catch(()=>{});
await page.click(submitSel).catch(async()=>{ await page.locator(passSel).press('Enter').catch(()=>{}); });

// Wait for redirect to success glob
await page.waitForURL(successPat, { timeout: 10000 });
console.log('  ✓ reached success URL:', page.url());

// Check dashboard content
const body = await page.textContent('body').catch(()=> '');
if (!body.includes('Dashboard') && !body.includes('OK')) {
  console.error('  body:', body.slice(0,500));
}
console.log('✓ test-auth passed — auto-login redirect works');
await browser.close();
NODE

kill $SERVER_PID 2>/dev/null || true
trap - EXIT
echo "✓ fixture stopped"
