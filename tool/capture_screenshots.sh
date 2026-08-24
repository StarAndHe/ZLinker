#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=docs/screenshots
PORT=8765
mkdir -p "$OUT"

if [[ ! -d tool/node_modules/puppeteer ]]; then
  echo "Installing puppeteer..."
  npm --prefix tool install puppeteer@24 >/dev/null
fi

echo "Building web screenshot demo..."
flutter build web -t tool/screenshot_demo.dart --release --no-wasm-dry-run >/dev/null

fuser -k "${PORT}/tcp" 2>/dev/null || true
python3 -m http.server "$PORT" --directory build/web >/dev/null 2>&1 &
srv=$!
sleep 1

SHOT_PORT="$PORT" node tool/capture_screenshots.mjs

kill "$srv" 2>/dev/null || true
wait "$srv" 2>/dev/null || true

if command -v convert >/dev/null 2>&1; then
  convert -delay 80 -loop 0 \
    "$OUT/01-list-mobile.png" \
    "$OUT/02-chat-mobile.png" \
    "$OUT/03-dual-pane.png" \
    -layers Optimize "$OUT/demo.gif"
fi

echo "Done: $OUT"
