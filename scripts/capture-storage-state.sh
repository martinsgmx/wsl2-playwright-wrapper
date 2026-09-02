#!/usr/bin/env bash
set -euo pipefail
# One-time helper: open headed browser, let user log in manually, save storageState to config/storage-state.json
# Uses Playwright directly (not MCP). Useful when auto-fill fails (captcha/SSO).
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$ROOT/config/storage-state.json"
AUTH_URL="${AUTH_URL:-http://localhost:3000/login}"

echo "→ capture-storage-state → $OUTPUT"
echo "  AUTH_URL=$AUTH_URL  (override via AUTH_URL env)"
echo "  Will open headed Chromium — log in manually, then press Enter here to save."

if [[ ! -f "$ROOT/.secrets.env" ]] && [[ -f "$ROOT/.secrets.env.example" ]]; then
  echo "  Note: .secrets.env not found — storage-state will still be saved"
fi

node << 'NODE'
import { chromium } from 'playwright';
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { resolve } from 'path';
import readline from 'readline';

const root = new URL('..', import.meta.url).pathname;
const out = resolve(root, 'config/storage-state.json');
let authUrl = process.env.AUTH_URL || 'http://localhost:3000/login';
try {
  const env = readFileSync(resolve(root, '.secrets.env'), 'utf8');
  for (const line of env.split('\n')) {
    const m = line.match(/^\s*AUTH_URL\s*=\s*(.*)\s*$/);
    if (m) authUrl = m[1].trim();
  }
} catch {}

const browser = await chromium.launch({ headless: false });
const context = await browser.newContext();
const page = await context.newPage();
await page.goto(authUrl);
console.log(`→ Opened ${authUrl} — log in now, then press Enter to save...`);

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
await new Promise(res => rl.question('Press Enter when logged in (at dashboard)...', () => { rl.close(); res(); }));

const state = await context.storageState();
writeFileSync(out, JSON.stringify(state, null, 2));
console.log(`✓ Saved storageState to ${out} — ${state.cookies.length} cookies`);
await browser.close();
NODE

chmod 600 "$OUTPUT" 2>/dev/null || true
echo "✓ Done — future isolated sessions will seed from config/storage-state.json"
echo "  To clear: rm config/storage-state.json && cp config/storage-state.example.json config/storage-state.json"
