# Demo recording tool

Records a polished, scripted screen recording of the **real** ZLinker web app
(`lib/main.dart`) — with an animated fake cursor, click ripples, a
zoom-in-on-tap effect and Chinese caption pills — for the
"empty list → paste URL → add device → device appears → settings" flow.

<p align="center">
  <video src="../docs/demo/zlinker-add-device.mp4" width="300" controls></video>
</p>

## Run it

```bash
tool/record_demo.sh
# -> docs/demo/zlinker-add-device.mp4
```

Options (env vars):

| Var | Default | Meaning |
| --- | --- | --- |
| `DEMO_OUT` | `docs/demo/zlinker-add-device.mp4` | Output path (`.mp4`) |
| `DEMO_PORT` | `8890` | Local static-server port |
| `DEMO_NO_CAPTIONS` | _(unset)_ | Set to `1` to hide the caption pills |
| `DEMO_KEEP_WEBM` | _(unset)_ | Keep the intermediate `.webm` |

Requirements: `flutter`, `node`, `python3`, `ffmpeg`. Puppeteer is installed
into `tool/node_modules` automatically on first run.

## How it works

- `tool/record_demo.sh` builds `build/web`, serves it, then runs the recorder.
- `tool/demo_recorder.mjs` (Puppeteer) opens the app in a phone-sized viewport
  (430×932 @2x), injects an overlay layer (SVG cursor, ripple, caption pill),
  and animates a CSS `transform: scale()` on the `<flutter-view>` to zoom.
  The zoom is centered on the tap point (its transform-origin), so the tapped
  pixel is the scale's fixed point — clicks land on the right widget even
  while zoomed.
- The browser viewport is captured with `page.screencast()` (webm), then
  transcoded to an H.264 `.mp4` with `ffmpeg`.

## Editing the flow

Everything is declarative in the `STEPS` array at the top of
`tool/demo_recorder.mjs`. Each step is a tap, a type action, or a pause:

```js
{ kind: 'tap',  x: 350, y: 892, zoom: 1.35, caption: '点击「添加设备」' }
{ kind: 'type', text: 'https://…', zoomAt: [215, 462], zoom: 1.5 }
{ kind: 'pause', ms: 1200, caption: '设备已出现在列表' }
```

Coordinates are CSS pixels for the 430×932 viewport. Because Flutter web
renders to a canvas (no stable DOM selectors in release builds), taps are
coordinate-based. If the UI layout changes, re-capture coordinates: run the
app, screenshot at that viewport, and read off the new positions.

## Note on the original Cursor cloud-agent clip

The very first demo GIF/clip in the chat was produced by Cursor's built-in
cloud-agent screen recorder; the click highlight/zoom polish there is an
automatic post-processing effect of that recorder, which is part of the agent
environment (not the repo). This tool reproduces the same feel with a
committed, reusable script you can run yourself.
