param(
  [int]$Port = 9222,
  [string]$UserDataDir = "",
  [string]$Browser = "auto"
)

# Finds Brave/Chrome/Edge and launches with --remote-debugging-port for WSL CDP attach.
# Mirrored WSL → --remote-debugging-address=127.0.0.1; NAT fallback would be 0.0.0.0 (not default).

function Find-Browser {
  param([string]$pref)
  $candidates = @()
  if ($pref -eq "auto" -or $pref -eq "brave") {
    $candidates += @(
      "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe",
      "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser\Application\brave.exe",
      "$env:LocalAppData\BraveSoftware\Brave-Browser\Application\brave.exe"
    )
  }
  if ($pref -eq "auto" -or $pref -eq "chrome") {
    $candidates += @(
      "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
      "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
      "$env:LocalAppData\Google\Chrome\Application\chrome.exe"
    )
  }
  if ($pref -eq "auto" -or $pref -eq "edge") {
    $candidates += @(
      "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
      "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    )
  }
  foreach ($p in $candidates) {
    if (Test-Path $p) { return $p }
  }
  # fallback: where.exe
  foreach ($name in @("brave","chrome","msedge")) {
    try { $hit = (Get-Command "$name.exe" -ErrorAction SilentlyContinue).Source; if ($hit) { return $hit } } catch {}
  }
  return $null
}

$exe = Find-Browser -pref $Browser
if (-not $exe) {
  Write-Error "No Brave/Chrome/Edge found. Install Brave or pass -Browser chrome/edge or edit script."
  exit 1
}
Write-Host "> Browser: $exe" -ForegroundColor Cyan

# Check port free
$inUse = $false
try {
  $c = Test-NetConnection -ComputerName "127.0.0.1" -Port $Port -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
  if ($c.TcpTestSucceeded) { $inUse = $true }
} catch {
  $net = netstat -ano | Select-String ":$Port"
  if ($net) { $inUse = $true }
}
if ($inUse) {
  Write-Host "> Port $Port already in use - checking if it's already CDP..." -ForegroundColor Yellow
  try {
    $r = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json/version" -TimeoutSec 2 -ErrorAction Stop
    Write-Host "OK CDP already up at http://127.0.0.1:$Port - webSocketDebuggerUrl: $($r.webSocketDebuggerUrl)" -ForegroundColor Green
    exit 0
  } catch {
    Write-Host "> CDP check failed ($($_.Exception.Message)) - will try to launch anyway; if port stays busy, use -Port <other>" -ForegroundColor Yellow
    # Don't exit 1 - let caller poll; brave may still be starting
  }
}

$addr = "127.0.0.1"
$argsList = "--remote-debugging-port=$Port --remote-debugging-address=$addr --no-first-run --no-default-browser-check"
if ($UserDataDir -ne "") {
  $argsList += " --user-data-dir=`"$UserDataDir`""
}

Write-Host "> Launching: `"$exe`" $argsList" -ForegroundColor Cyan
Start-Process -FilePath $exe -ArgumentList $argsList

# Poll CDP (use 127.0.0.1 to avoid localhost ::1 timeout on some Windows)
for ($i=0; $i -lt 20; $i++) {
  Start-Sleep -Milliseconds 500
  try {
    $r = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json/version" -TimeoutSec 2 -ErrorAction Stop
    Write-Host "OK CDP ready at http://127.0.0.1:$Port - $($r.Browser) - webSocketDebuggerUrl: $($r.webSocketDebuggerUrl)" -ForegroundColor Green
    exit 0
  } catch {
    # ignore, will retry
  }
}
Write-Warning "Launched but CDP not responding at http://127.0.0.1:$Port/json/version after 10s. Check firewall or try again."
exit 1
