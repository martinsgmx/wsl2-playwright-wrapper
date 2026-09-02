# Auth — isolated sessions + login until redirect (playwright-wrapper-mcp)

## Why isolated

`--isolated` gives each MCP session a fresh `BrowserContext` inside the headed Windows Brave. No cookies, no localStorage bleed. You see the window, but each `browser_close` wipes state. This is intentional for debugging prod-like flows and avoiding stale logins.

Consequence: you **see the login form every new session** unless you seed it.

## Two ways to seed

### A) `--storage-state` (pre-authenticated, fastest)

```bash
bash scripts/capture-storage-state.sh
# opens headed Chromium at $AUTH_URL → you log in manually → press Enter → writes config/storage-state.json
```

Future isolated sessions load `config/storage-state.json` via `--storage-state`, so they start already logged in and `init-auth.ts` becomes a no-op (it detects already on `AUTH_SUCCESS_PATH`).

Use when: SSO, captcha, 2FA, or brittle selectors. Don't commit the file if it has real session cookies.

To clear: `rm config/storage-state.json; cp config/storage-state.example.json config/storage-state.json`

### B) `--secrets` + `--init-page` (auto-fill until redirect)

`--secrets .secrets.env` loads `AUTH_*` vars into `process.env` for `scripts/init-auth.ts`, which is evaluated on every new page creation:

- only acts when `page.url()` contains `AUTH_URL` pathname,
- fills `AUTH_USER_SELECTOR`/`AUTH_PASS_SELECTOR` with `AUTH_USERNAME`/`PASSWORD`,
- clicks `AUTH_SUBMIT_SELECTOR` (fallback: press Enter),
- `await page.waitForURL(AUTH_SUCCESS_PATH, { timeout: 15000 })`.

Configure `AUTH_SUCCESS_PATH` as a glob: `**/dashboard**`, `**/app/**`, or full `http://localhost:3000/dashboard`.

Use when: simple form login without captcha/SSO, and you want zero manual steps per session. Keep secrets in `.secrets.env` (`chmod 600`, gitignored).

You can **combine both**: if `storage-state` is present, sessions start logged in; if expired, `init-auth` re-logs.

## Init hook details

`scripts/init-auth.ts` is a Playwright `init-page` export:

```ts
export default async ({ page }) => { /* fill + waitForURL */ }
```

It never throws — failures are swallowed so session creation isn't broken. Selector heuristics cover `input[type="email"], input[name="username"]` etc.; override via `AUTH_USER_SELECTOR` etc. if your app uses `data-testid`.

## Troubleshooting login

- Check `AUTH_URL` pathname actually matches the page you navigate to (e.g. `/login` vs `/signin`).
- If `waitForURL` times out, the glob may be wrong — try `**/dashboard**` vs exact host + `curl` the redirect.
- If captcha/SSO, use capture-storage-state instead.
- Run `bash scripts/test-auth.sh` against the fixture to prove the mechanism works before pointing at your real app.
