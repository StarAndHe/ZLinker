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

# Pick the first interpreter that actually RUNS — Windows ships a
# WindowsApps "python3.exe" stub that exists on PATH but only opens the
# Microsoft Store, so Get-Command alone is not enough.
$Py = $null
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"  # native stubs write to stderr; don't abort
foreach ($c in @("python3", "python")) {
    (& $c -c "import sys") 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { $Py = $c; break }
}
$ErrorActionPreference = $prevEap
if (-not $Py) { Write-Error "no working python interpreter on PATH" }

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
# --no-web-resources-cdn: keep canvaskit/fonts local so the recording does not
# depend on gstatic reachability (fails with ERR_CERT_* on some networks).
flutter build web --dart-define=APP_CHANNEL=github --no-web-resources-cdn | Out-Null

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
    # Poll until the static server answers (python cold start can exceed a
    # fixed sleep after a heavy flutter build).
    $ready = $false
    for ($i = 0; $i -lt 30; $i++) {
        try {
            $r = Invoke-WebRequest -Uri "http://127.0.0.1:${Port}/index.html" `
                -UseBasicParsing -TimeoutSec 2
            if ($r.StatusCode -eq 200) { $ready = $true; break }
        } catch { Start-Sleep -Milliseconds 500 }
    }
    if (-not $ready) { Write-Error "static server on port $Port never became ready" }
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
