# Installation

## Prereqs

- **WSL2** with `mirrored` networking (this repo's box is `mirrored` — `cat /etc/wsl.conf`, `wslinfo --networking-mode`). NAT also works via fallback.
- **Windows Chrome/Brave/Edge** (Chromium-family; the CDP flow). Brave at `C:\Program Files\BraveSoftware\...` auto-detected when `BROWSER=auto`, or choose `BROWSER=chrome` / `BROWSER=edge`. Firefox is NOT supported (it uses WebDriver BiDi, not CDP).
- **Node 18+** in WSL (`node -v`), `npm`, `curl`, `python3` (for JSON pretty-print).
- **opencode** `1.18+` (`opencode --version`) — https://opencode.ai/docs

## 1) Launch a Chromium browser with CDP

**From WSL:**

```bash
bash scripts/launch-browser-debug.sh                      # BROWSER=auto → Brave
BROWSER=chrome bash scripts/launch-browser-debug.sh       # Chrome
BROWSER=edge  bash scripts/launch-browser-debug.sh        # Edge
# optional: CDP_PORT=9223 bash scripts/launch-browser-debug.sh
```

**From Windows (Explorer):**

Double-click `scripts/launch-browser-debug.cmd` (calls `launch-browser-debug.ps1` with `-ExecutionPolicy Bypass`).

What it does: starts the chosen browser with `--remote-debugging-port=9222 --remote-debugging-address=127.0.0.1`, polls `http://localhost:9222/json/version`. Each brand uses a dedicated named profile at `C:\Users\<you>\AppData\Local\Playwright\<browser>` so launches never collide with your everyday browser profile (and re-launching while open reuses the existing CDP session).

**Verify from WSL:**

```bash
bash scripts/check-cdp.sh
curl http://localhost:9222/json/version | python3 -m json.tool
```

If `mirrored`, `localhost` is shared. If `NAT`, the wrapper auto-picks gateway via `ip route show default`; Brave must then use `0.0.0.0` with a scoped firewall rule (see troubleshooting).

## 2) WSL wiring — project `opencode.jsonc`

```bash
bash scripts/setup-mcp.sh
```

This:
- checks `node -v >=18`, runs `npm install` (adds `playwright` for `capture-storage-state`),
- probes `npx -y @playwright/mcp@latest --version`,
- creates `.secrets.env` from `.secrets.env.example` if missing (`chmod 600`),
- creates `config/storage-state.json` from example if missing,
- `chmod +x scripts/*.sh`,
- runs `opencode mcp list` (non-fatal if CDP not up yet).

The project `opencode.jsonc` at repo root is:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": { "playwright": { "type": "local", "command": ["bash", "scripts/mcp-wrapper.sh"], "enabled": true, "timeout": 10000 } }
}
```

It uses `scripts/mcp-wrapper.sh` which expands to:

```
npx @playwright/mcp --cdp-endpoint http://<host>:<port> --isolated
  --secrets .secrets.env --init-page scripts/init-auth.ts
  --storage-state config/storage-state.json --caps devtools
```

`--storage-state` is omitted if the file is missing/empty. No creds in `opencode.jsonc`.

## 3) Secrets — login until redirect

```bash
cp .secrets.env.example .secrets.env
$EDITOR .secrets.env
```

Set:

```
AUTH_URL=http://localhost:3000/login        # page that shows the form
AUTH_USERNAME=you@example.com
AUTH_PASSWORD=secret
AUTH_SUCCESS_PATH=**/dashboard**             # glob — waitForURL until redirect hits this
CDP_PORT=9222
# optional overrides:
# AUTH_USER_SELECTOR=input[name="username"]
# AUTH_PASS_SELECTOR=input[name="password"]
# AUTH_SUBMIT_SELECTOR=button[type="submit"]
```

Permissions: `chmod 600 .secrets.env` (done by setup). File is **gitignored** — never commit.

Optional seed (skips form in future isolated sessions):

```bash
bash scripts/capture-storage-state.sh   # opens headed Chromium, you log in once, Enter → writes config/storage-state.json
```

Also gitignored (or commit only `storage-state.example.json`).

## 4) Verify

```bash
opencode mcp list                 # playwright → enabled
opencode mcp debug playwright     # shows endpoint, isolated

bash scripts/smoke-test.sh        # CDP → https://example.com
bash scripts/test-isolated.sh     # proves isolation
bash scripts/test-auth.sh         # fixture login → dashboard (uses .secrets.env)

opencode                          # TUI → "use playwright to navigate to $AUTH_URL and report after login"
```

`opencode` merges global `~/.config/opencode/opencode.jsonc` + project `opencode.jsonc` (project wins) per https://opencode.ai/docs/config/#precedence-order.

## Windows Startup (optional)

To auto-launch Brave CDP at login, create a Task Scheduler entry that runs:

```
powershell -ExecutionPolicy Bypass -File C:\path\to\wsl-chrome\scripts\launch-browser-debug.ps1 -Port 9222
```

## Updating

- `npx -y @playwright/mcp@latest --version` — MCP is fetched via `npx` on each spawn, so it auto-updates; pin in `mcp-wrapper.sh` if needed.
- `npm update` for `playwright` devDep.
