#!/usr/bin/env bash
# Build the ZLinker web app and record a scripted, polished demo video
# (animated cursor + click ripples + zoom-on-tap) of the add-device flow.
#
#   tool/record_demo.sh                      # -> docs/demo/zlinker-add-device.mp4
#   DEMO_OUT=build/demo/x.mp4 tool/record_demo.sh
#   DEMO_NO_CAPTIONS=1 tool/record_demo.sh   # no caption pills
#
# Requires: flutter, python3, ffmpeg, and node (puppeteer auto-installed).
set -euo pipefail
cd "$(dirname "$0")/.."

PORT="${DEMO_PORT:-8890}"
OUT="${DEMO_OUT:-docs/demo/zlinker-add-device.mp4}"

command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg is required (apt-get install ffmpeg)"; exit 1; }

if [[ ! -d tool/node_modules/puppeteer ]]; then
  echo "Installing puppeteer..."
  npm --prefix tool install puppeteer@24 >/dev/null
fi

echo "Building web app (lib/main.dart)..."
flutter build web --dart-define=APP_CHANNEL=github >/dev/null

fuser -k "${PORT}/tcp" 2>/dev/null || true
python3 -m http.server "$PORT" --directory build/web >/dev/null 2>&1 &
srv=$!
trap 'kill "$srv" 2>/dev/null || true' EXIT
sleep 1.5

mkdir -p "$(dirname "$OUT")"
echo "Recording demo -> $OUT"
DEMO_URL="http://127.0.0.1:${PORT}/index.html" DEMO_OUT="$OUT" node tool/demo_recorder.mjs

echo "Done: $OUT"
