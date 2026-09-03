# Scripts Reference

All scripts are `chmod +x`, `set -euo pipefail`, and use absolute Windows paths for `appendWindowsPath=false` compatibility.

| Script | Purpose | Key flags / env |
|---|---|---|
| `scripts/launch-browser-debug.ps1` | Windows PowerShell launcher | `-Port 9222 -Browser auto|brave|chrome|edge -UserDataDir ""` |
| `scripts/launch-browser-debug.cmd` | Batch double-click wrapper | calls `.ps1` with Bypass |
| `scripts/launch-browser-debug.sh` | WSL shim | `CDP_PORT`, `CDP_ADDR`, `BROWSER`, `CDP_USER_DATA_DIR` |
| `scripts/wsl-host-ip.sh` | Prints `localhost` (mirrored) or gateway (NAT) | respects `CDP_HOST` |
| `scripts/check-cdp.sh` | `curl /json/version` health | `CDP_PORT`, uses `wsl-host-ip.sh` |
| `scripts/mcp-wrapper.sh` | MCP entry for `opencode.jsonc` | builds `npx @playwright/mcp --isolated --cdp-endpoint ... --secrets --init-page --storage-state --caps devtools` |
| `scripts/install.sh` | One-command installer | clones into `~/.opencode/wsl-chrome`, `npm install`, writes `./opencode.jsonc` |
| `scripts/init-auth.ts` | `--init-page` auto-login hook | reads `AUTH_*` from `process.env` (via `--secrets`) |
| `scripts/setup-mcp.sh` | Idempotent installer | checks node, `npm install`, creates `.secrets.env`/`config/storage-state.json` |
| `scripts/capture-storage-state.sh` | Manual login → `config/storage-state.json` | uses `playwright` headed |
| `scripts/smoke-test.sh` | CDP → example.com + wrapper probe | falls back to direct headless if CDP down |
| `scripts/test-isolated.sh` | Proves no bleed between contexts | CDP or direct fallback |
| `scripts/test-auth.sh` | Fixture `login → 302 /dashboard` | `FIXTURE_PORT=3335`, `AUTH_*` from `.secrets.env`, CDP or direct fallback |

Logs: `check-cdp` JSON to stdout, fixture logs to `/tmp/opencode/fixture-test-auth.log` when run via `test-auth.sh`.

Common env: `CDP_PORT=9222`, `CDP_HOST`, `BROWSER=auto|brave|chrome|edge`, `CDP_USER_DATA_DIR`, `AUTH_URL`, `AUTH_USERNAME`, `AUTH_PASSWORD`, `AUTH_SUCCESS_PATH="**/dashboard**"`, `AUTH_USER_SELECTOR`, etc.

Run: `bash scripts/<name>.sh` from WSL, or double-click `.cmd` on Windows. Choose the browser with `BROWSER=chrome bash scripts/launch-browser-debug.sh` (default `auto` → Brave). Chromium-family only (Chrome/Brave/Edge); Firefox isn't CDP-attachable.
