# Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `curl http://localhost:9222/json/version` → `Failed to connect` | Brave not launched with CDP | `bash scripts/launch-browser-debug.sh` (WSL) or double-click `scripts/launch-browser-debug.cmd` (Windows). Then `bash scripts/check-cdp.sh`. |
| `Port 9222 already in use` | Another debug Brave / VS Code / old instance | `netstat -ano \| findstr :9222` (Windows) → kill holder or `CDP_PORT=9223 bash scripts/launch-browser-debug.sh` and set `CDP_PORT=9223` in `.secrets.env`. |
| CDP reachable on Windows but `curl` from WSL times out | WSL `NAT` mode + `127.0.0.1` bind | `wslinfo --networking-mode` → if `nat`, launch Brave with `--remote-debugging-address=0.0.0.0` and add scoped firewall: `New-NetFirewallRule -DisplayName "WSL Brave CDP" -Direction Inbound -LocalPort 9222 -Protocol TCP -RemoteAddress 172.16.0.0/12 -Action Allow`. Mirrored mode (this box) needs no rule. |
| `powershell.exe not found` | `appendWindowsPath=false` | Scripts use absolute `/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe` — keep it, or use Windows double-click path. |
| `opencode mcp list` shows `playwright` failed | `@playwright/mcp` not fetched / CDP down | `npx -y @playwright/mcp@latest --version`, `bash scripts/check-cdp.sh`, `opencode mcp debug playwright`. |
| Login form not auto-filled | Wrong `AUTH_URL` pathname or selectors | Set `AUTH_URL` to full login URL, override `AUTH_USER_SELECTOR`/`PASS`/`SUBMIT` in `.secrets.env` to match your app's `data-testid`. Test against fixture: `bash scripts/test-auth.sh`. |
| `waitForURL(**/dashboard**) timeout` | Glob doesn't match real redirect | `curl -v` the login POST, note `Location:` header, set `AUTH_SUCCESS_PATH` to that glob or full URL. |
| Captcha / SSO / 2FA blocks auto-fill | `--secrets` can't solve | Use `bash scripts/capture-storage-state.sh` — manual one-time login → `config/storage-state.json` seeds future isolated sessions. |
| Brave update wiped flags | Update restarts Brave without CDP | Always launch via script; optional Task Scheduler entry for CDP at login (see installation). |
| `storage-state.json` has stale cookies | Session expired | `rm config/storage-state.json; cp config/storage-state.example.json config/storage-state.json` and recapture or rely on `init-auth` re-login. |

## Diagnostics

```bash
bash scripts/wsl-host-ip.sh        # what host wrapper will use
bash scripts/check-cdp.sh           # CDP JSON + webSocketDebuggerUrl
curl -s http://localhost:9222/json/list | python3 -m json.tool   # open targets
opencode mcp debug playwright
```
