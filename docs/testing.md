# Testing

5 checks — CDP health, MCP wiring, smoke, isolation, auth-redirect.

| # | Command | Proves | Needs |
|---|---|---|---|
| 1 | `bash scripts/check-cdp.sh` | Brave CDP reachable from WSL (`ws://...`) | Brave launched via `launch-brave-debug.*` |
| 2 | `bash scripts/setup-mcp.sh && opencode mcp list` | `@playwright/mcp` installed, `opencode.jsonc` valid | Node 18+, opencode |
| 3 | `bash scripts/smoke-test.sh` | `chromium.connectOverCDP → goto example.com → title` in isolated context | `check-cdp` passes |
| 4 | `bash scripts/test-isolated.sh` | `--isolated` wipes cookies between sessions (no bleed) | `check-cdp` passes |
| 5 | `bash scripts/test-auth.sh` | Fixture `POST /login → 302 /dashboard` auto-filled via `init-auth` logic until `AUTH_SUCCESS_PATH` | `check-cdp` passes |

## Fixture

`test/fixtures/login/server.js` is a tiny Node `http` server:

- `GET /login` → form (`username`/`password`)
- `POST /login` → if `username==AUTH_USERNAME && password==AUTH_PASSWORD` → `302 /dashboard` + `Set-Cookie: session=ok`, else 401
- `GET /dashboard` → requires cookie, else redirect to `/login`

`test-auth.sh` starts it on `FIXTURE_PORT=3000`, waits, runs Playwright `connectOverCDP` + fill + `waitForURL("**/dashboard**")`, stops server. Respects `.secrets.env` if present.

Run manually:

```bash
FIXTURE_PORT=3000 AUTH_USERNAME=test@example.com AUTH_PASSWORD=test123 bash scripts/test-auth.sh
```

## Manual LLM test

```bash
opencode
# in TUI:  use playwright to navigate to http://localhost:3000/login and report the title after login
# (with fixture server running: node test/fixtures/login/server.js)
```

With `opencode.jsonc` active, the LLM has `playwright_*` tools (navigate, snapshot, click, fill, evaluate, console).

## CI note

No Windows Brave? `smoke-test.sh` fallback: run `npx @playwright/mcp --isolated --headless` ephemeral or `npx playwright` directly. But primary target is headed Windows CDP.
