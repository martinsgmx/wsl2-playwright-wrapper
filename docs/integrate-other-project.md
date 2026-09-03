# Integrate into another project (keep your Playwright install)

This repo is **injection / config only** for WSL2. It does **not** replace or reinstall
Playwright MCP in another project — it gives that project the two missing pieces that fix
the `MCP error -32001: Request timed out` you see when Playwright MCP can't reach a browser:

1. **A CDP launcher** for your visible Windows Brave/Chrome (`scripts/launch-browser-debug.sh` + friends).
2. **A CDP endpoint pointer** added to that project's `opencode.jsonc`
   (`--cdp-endpoint http://localhost:9222`).

You keep the official `npm i -D @playwright/mcp` install and **every** Playwright command
(`browser_navigate`, `browser_snapshot`, `browser_click`, `browser_evaluate`,
`browser_console_messages`, `browser_network_requests`, `browser_take_screenshot`, …)
works exactly as in this repo.

---

## Why you get `Request timed out`

`@playwright/mcp` launched per official docs tries to drive a browser. In WSL, the bundled
Chromium has **no display**, and your real browser lives on **Windows** with **no CDP server**
running. So every navigation times out with:

```
MCP error -32001: Request timed out
```

The fix is a one-liner: give MCP a live `--cdp-endpoint`. Nothing else changes.

---

## Option A — Minimal (recommended): just add CDP

You only touch **one file** in the other project.

### 1) Copy the CDP launcher (one-time)

```bash
# from this repo into the other project
cp /path/to/wsl-chrome/scripts/launch-browser-debug.sh /path/to/your-project/scripts/
cp /path/to/wsl-chrome/scripts/launch-browser-debug.ps1 /path/to/your-project/scripts/
cp /path/to/wsl-chrome/scripts/launch-browser-debug.cmd /path/to/your-project/scripts/
cp /path/to/wsl-chrome/scripts/wsl-host-ip.sh /path/to/your-project/scripts/
cp /path/to/wsl-chrome/scripts/check-cdp.sh /path/to/your-project/scripts/
chmod +x /path/to/your-project/scripts/*.sh
```

### 2) Launch Windows Brave with CDP (every session)

```bash
bash scripts/launch-browser-debug.sh   # no-op if CDP already running
bash scripts/check-cdp.sh            # → ✓ CDP reachable
```

### 3) Point your existing Playwright MCP at CDP

Edit the other project's `opencode.jsonc`. If it doesn't exist yet, create it. Just add
`--cdp-endpoint http://localhost:9222` to the `command`:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "playwright": {
      "type": "local",
      "command": [
        "npx", "@playwright/mcp@latest",
        "--cdp-endpoint", "http://localhost:9222"
      ],
      "enabled": true,
      "timeout": 10000
    }
  }
}
```

That's it. Run `opencode`, and Playwright drives your **visible Windows Brave** in the other
project with zero loss of commands.

---

## Option B — Full wrapper (add isolation + auth until redirect)

Only if you also want the isolated sessions / storage-state / auto-login features this repo
offers. Copy the whole `scripts/` + `config/` and switch the command to the wrapper:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "playwright": {
      "type": "local",
      "command": ["bash", "scripts/mcp-wrapper.sh"],
      "enabled": true,
      "timeout": 10000
    }
  }
}
```

`scripts/mcp-wrapper.sh` auto-detects the WSL host (mirrored vs NAT), injects
`--cdp-endpoint`, and adds `--isolated --secrets --init-page --storage-state`. See
`configuration.md` and `auth.md` for the flags and `.secrets.env` vars.

---

## Which to choose

| You want | Use |
|---|---|
| Keep official Playwright install, stop the timeout | **Option A** |
| Isolated sessions, no cookie bleed | Option B (has `--isolated`) |
| Auto-login until redirect (`init-auth.ts`) | Option B |
| Seed cookies to skip login | Option B + `capture-storage-state.sh` |

Both keep every Playwright CLI capability. The repo's `scripts/mcp-wrapper.sh` is just a thin
convenience wrapper over `@playwright/mcp` — it never forks or swaps the MCP server.