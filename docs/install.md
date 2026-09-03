# One-command install (OpenCode + Playwright MCP, WSL2)

Give any project browser-debugging in OpenCode with a single command. The installer clones this
repo **globally** (so it stays **out of your project's git tracking**), installs the Playwright
dependency, and wires the project's `opencode.jsonc` to OpenCode's MCP.

> This is **injection/config only** — it never replaces or forks `@playwright/mcp`. You keep
> every Playwright command. See [`integrate-other-project.md`](integrate-other-project.md).

## One-liner

From a WSL2 shell, inside the project you want browser access in:

```bash
curl -fsSL https://raw.githubusercontent.com/martinsgmx/wsl2-playwright-wrapper/main/install.sh | bash
```

## What it does

1. **Clones** `wsl2-playwright-wrapper` into `~/.opencode/wsl-chrome` (global). If it already
   exists, it fetches the latest (`git pull` / `reset --hard origin/main`).
2. **npm install** in that clone so the `playwright` dependency is installed
   (used by `capture-storage-state.sh`; the MCP server itself is fetched by `npx` on demand).
3. **Auto-writes** `./opencode.jsonc` in the current project so OpenCode's MCP `playwright`
   entry points at the wrapper's **absolute path**:
   ```jsonc
   { "mcp": { "playwright": { "type": "local",
       "command": ["bash", "/home/<you>/.opencode/wsl-chrome/scripts/mcp-wrapper.sh"],
       "enabled": true, "timeout": 10000 } } }
   ```
   - If `opencode.jsonc` already exists **without** the wrapper, it asks before overwriting.
   - If it already points at the wrapper, it leaves it alone (idempotent).
4. **Creates** `~/.opencode/wsl-chrome/.secrets.env` from the example (`chmod 600`) for auth —
   edit it to set `AUTH_URL`, `AUTH_USERNAME`, `AUTH_PASSWORD`, `AUTH_SUCCESS_PATH`.
5. **Checks CDP** (non-fatal) and prints next steps.

## After install

```bash
bash ~/.opencode/wsl-chrome/scripts/launch-browser-debug.sh   # BROWSER=auto|chrome|edge
bash ~/.opencode/wsl-chrome/scripts/check-cdp.sh
opencode
# in the TUI:   use playwright to navigate to https://example.com/ and report console errors
```

## Overrides

| Env var | Default | Meaning |
|---|---|---|
| `WSL_PW_INSTALL_DIR` | `$HOME/.opencode/wsl-chrome` | Where the repo is cloned |
| `WSL_PW_REPO_URL` | `https://github.com/martinsgmx/wsl2-playwright-wrapper.git` | Repo to clone |
| `OPENCODE_JSONC` | `./opencode.jsonc` | Project config file to write |

Example:
```bash
WSL_PW_INSTALL_DIR="$HOME/.opencode/pw" \
curl -fsSL https://raw.githubusercontent.com/martinsgmx/wsl2-playwright-wrapper/main/install.sh | bash
```

## Run it manually (offline / local dev)

```bash
git clone https://github.com/martinsgmx/wsl2-playwright-wrapper.git ~/.opencode/wsl-chrome
bash ~/.opencode/wsl-chrome/scripts/install.sh     # same logic, no curl
```

## Why global (not in the project)?

- The wrapper lives at `~/.opencode/wsl-chrome`, shared across all projects — install once.
- There's **nothing to gitignore** in the target project: the MCP command uses an absolute path
  to the global clone, and the clone never exists inside the project's git tree.
- Your project's `opencode.jsonc` (with the one-line absolute-path entry) is the only file that
  changes, and you can commit it or not as you prefer.
