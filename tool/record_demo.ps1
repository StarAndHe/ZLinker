# Windows version of tool/record_demo.sh — records the scripted ZLinker demo
# video (animated cursor + click ripple + zoom-on-tap) from the real web app.
#
#   powershell -ExecutionPolicy Bypass -File tool/record_demo.ps1
#   # overrides:
#   $env:DEMO_OUT = "build/demo/x.mp4"; powershell ... -File tool/record_demo.ps1
#
# Requires: flutter, node (npm), python, ffmpeg on PATH.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$Port = if ($env:DEMO_PORT) { $env:DEMO_PORT } else { 8890 }
$Out = if ($env:DEMO_OUT) { $env:DEMO_OUT } else { "docs/demo/zlinker-add-device.mp4" }
$Py = if (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" } else { "python" }

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Error "ffmpeg is required on PATH"
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "node (npm) is required on PATH"
}

if (-not (Test-Path "tool/node_modules/puppeteer")) {
    Write-Host "Installing puppeteer..."
    npm --prefix tool install puppeteer@24 | Out-Null
}

Write-Host "Building web app (lib/main.dart)..."
flutter build web --dart-define=APP_CHANNEL=github | Out-Null

# Free the port if something is listening on it (Windows equivalent of fuser -k).
$conns = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($conns) {
    $conns | Select-Object -ExpandProperty OwningProcess -Unique |
        ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 500
}

$srv = Start-Process -FilePath $Py `
    -ArgumentList "-m", "http.server", "$Port", "--directory", "build/web" `
    -WindowStyle Hidden -PassThru
try {
    Start-Sleep -Seconds 2
    New-Item -ItemType Directory -Force -Path (Split-Path $Out) | Out-Null
    Write-Host "Recording demo -> $Out"
    $env:DEMO_URL = "http://127.0.0.1:${Port}/index.html"
    $env:DEMO_OUT = $Out
    node tool/demo_recorder.mjs
    if ($LASTEXITCODE -ne 0) { Write-Error "demo_recorder.mjs failed (exit $LASTEXITCODE)" }
} finally {
    if ($srv -and -not $srv.HasExited) { Stop-Process -Id $srv.Id -Force -ErrorAction SilentlyContinue }
}

Write-Host "Done: $Out"
