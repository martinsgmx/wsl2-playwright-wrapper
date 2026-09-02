# playwright-wrapper-mcp — Playwright MCP wrapper (WSL → Windows Brave)

> Folder stays `wsl-chrome` on disk; package/docs name is `playwright-wrapper-mcp` (wrapper over `@playwright/mcp`, not `chrome-mcp`).

Isolated, headed browser debugging: `opencode` runs in **WSL**, drives your **visible Windows Brave/Chrome** via CDP through a **Playwright MCP wrapper**. Every LLM session is **isolated** (fresh `BrowserContext` → no cookie bleed). Login gates are handled via config-driven auto-fill until a success redirect.

## What this repo is — and is not

This repo is **injection / config only** for WSL2. It is **not** a Playwright replacement:

- It **keeps** the official `@playwright/mcp` install and the **full Playwright command set**
  (`browser_navigate`, `browser_snapshot`, `browser_click`, `browser_evaluate`,
  `browser_console_messages`, `browser_network_requests`, `browser_take_screenshot`, …).
- It **adds** the two things a fresh project is missing that cause the
  `MCP error -32001: Request timed out`:
  1. a **CDP launcher** for your visible Windows Brave/Chrome, and
  2. a **`--cdp-endpoint http://localhost:9222`** pointer in the project's `opencode.jsonc`.

So you can replicate this working flow in **any other project** without losing any Playwright
tools. If you already installed Playwright per official docs (`npm i -D @playwright/mcp`),
you only change `command` to add the CDP endpoint — see
**[`docs/integrate-other-project.md`](docs/integrate-other-project.md)** for the copy-paste
setup (Option A = just add CDP, Option B = full wrapper with isolation + auth).

```
WSL opencode ──bash scripts/mcp-wrapper.sh──► npx @playwright/mcp --isolated --cdp-endpoint http://localhost:9222
                                                    --secrets .secrets.env --init-page scripts/init-auth.ts
                                                         │
Windows Brave  --remote-debugging-port=9222 ◄─────────────┘   headed window + isolated context
```

## Install in OpenCode

### Get the files

```bash
# clone
git clone https://github.com/martinsgmx/wsl-conf-mcp-chrome.git
cd wsl-chrome

# or copy into an existing project
cp -r /path/to/wsl-chrome/opencode.jsonc ./opencode.jsonc
cp -r /path/to/wsl-chrome/scripts ./scripts
cp /path/to/wsl-chrome/.secrets.env.example ./.secrets.env.example
mkdir -p config && cp /path/to/wsl-chrome/config/storage-state.example.json ./config/
```

Required: Node 18+, WSL2 mirrored (`wslinfo --networking-mode` → `mirrored`), Windows Brave/Chrome. See `docs/installation.md` for prereqs.

### Install

```bash
# 1) Launch Windows Brave with CDP (WSL or Windows double-click)
bash scripts/launch-brave-debug.sh
# or on Windows: double-click scripts/launch-brave-debug.cmd

# 2) Verify CDP from WSL
bash scripts/check-cdp.sh   # → ✓ CDP reachable — ws://localhost:9222/...
curl http://127.0.0.1:9222/json/version

# 3) Wire MCP (project-scoped, no global patch)
bash scripts/setup-mcp.sh        # node check, npm install, creates .secrets.env + config/storage-state.json
cp .secrets.env.example .secrets.env
$EDITOR .secrets.env              # set AUTH_URL, AUTH_USERNAME, AUTH_PASSWORD, AUTH_SUCCESS_PATH
chmod 600 .secrets.env

# 4) Verify in OpenCode
opencode mcp list                # playwright → connected (isolated)
opencode mcp debug playwright    # not a remote server, shows local command
```

`opencode.jsonc` is project-scoped — `opencode` merges `~/.config/opencode/opencode.jsonc` + `./opencode.jsonc` (project wins, per `https://opencode.ai/docs/config#precedence-order`). No global install needed; keep it in the repo.

### Use in OpenCode

```bash
opencode
# in TUI:
# > use playwright to navigate to https://example.com/ and report console errors
```

Every session is `--isolated` — see `docs/auth.md`. For first login with captcha/SSO, run `bash scripts/capture-storage-state.sh` once to seed `config/storage-state.json`.

### Quickstart (60s) — same as above, condensed

**1) Launch Windows Brave with CDP**

WSL:

```bash
bash scripts/launch-brave-debug.sh
```

Or Windows: double-click `scripts/launch-brave-debug.cmd`

Verify:

```bash
bash scripts/check-cdp.sh   # → ✓ CDP reachable — ws://localhost:9222/...
curl http://127.0.0.1:9222/json/version
```

**2) Install & configure (project-scoped)**

```bash
bash scripts/setup-mcp.sh        # node check, npm install, creates .secrets.env + config/storage-state.json
cp .secrets.env.example .secrets.env
# edit .secrets.env:
#   AUTH_URL=http://localhost:3000/login
#   AUTH_USERNAME=test@example.com
#   AUTH_PASSWORD=test123
#   AUTH_SUCCESS_PATH=**/dashboard**
chmod 600 .secrets.env
```

Optional — pre-seed cookies so future isolated sessions skip the form:

```bash
bash scripts/capture-storage-state.sh   # opens headed browser, you log in once, press Enter → writes config/storage-state.json
```

**3) Run**

```bash
opencode mcp list                # playwright → enabled (isolated)
bash scripts/smoke-test.sh       # CDP → example.com title
bash scripts/test-auth.sh        # fixture login → dashboard (auto-fill until redirect)
bash scripts/test-isolated.sh    # proves no bleed between sessions

opencode                         # then in TUI: "use playwright to navigate to $AUTH_URL and report after login"
```

## Repo layout

```
opencode.jsonc                 # project MCP (local → mcp-wrapper.sh, isolated)
.secrets.env.example           # copy to .secrets.env (gitignored)
config/storage-state.json      # gitignored seed cookies (optional)
config/storage-state.example.json
scripts/
  launch-brave-debug.ps1/.cmd/.sh
  wsl-host-ip.sh / check-cdp.sh / mcp-wrapper.sh
  init-auth.ts                 # auto-login until AUTH_SUCCESS_PATH
  setup-mcp.sh / capture-storage-state.sh
  smoke-test.sh / test-isolated.sh / test-auth.sh
test/fixtures/login/server.js  # tiny login→dashboard fixture for test-auth
docs/
  installation.md / configuration.md / auth.md / testing.md / troubleshooting.md
  integrate-other-project.md   # add CDP-only to any project, keep Playwright commands
```

## Configuration

See `docs/configuration.md` for `opencode.jsonc`, `mcp-wrapper.sh` flags, and `.secrets.env` vars (`AUTH_*`, `CDP_PORT`, `AUTH_SUCCESS_PATH` glob like `**/dashboard**`).

Use in another project (keep official Playwright install): `docs/integrate-other-project.md`.

Isolation note: every `browser_close` wipes the session. Next session re-logins via `init-auth.ts` or seeds from `config/storage-state.json` (faster). See `docs/auth.md`.

## Installation & testing

- Install: `docs/installation.md`
- Tests: `docs/testing.md` — 5 checks: `check-cdp`, `mcp list`, `smoke`, `test-isolated`, `test-auth`.

## Troubleshooting

- Port in use / firewall / NAT vs mirrored / Brave update → `docs/troubleshooting.md`
- `appendWindowsPath=false` is handled (scripts use absolute `/mnt/c/Windows/.../powershell.exe`).
