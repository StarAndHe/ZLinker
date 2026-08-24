# Store screenshots

Local tool (not in CI): captures the real pages with seeded fake data
(devices / task list / conversation / tablet dual-pane) on any connected
device or simulator.

## Layout

```
docs/screenshots/
├── raw/       untouched captures at render resolution (8 files)
├── iphone/    1290×2796  App Store 6.9"/6.7" slot (01–03) + 2732×2048 iPad 12.9" (04)
└── play/      1080×2400  Play phone (01–03) + 1920×1200 Play tablet (04)
```

- `raw/01|02|03-*` are 1440×3036 portraits from the phone profile
- `raw/04-dualpane-*` is 2752×1914 landscape from the tablet profile
- Each store set is `{01-devices,02-tasks,03-chat,04-dualpane}-{en,zh}.png`

## Capture

Two runs (zh + en), driven through `test_driver/integration_test.dart`,
which unpacks each `takeScreenshot()` payload into a PNG:

```bash
export JAVA_HOME="D:/Android"   # JDK 17+ next to the Android SDK

ZLINKER_SHOT_DIR=docs/screenshots/raw flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart -d <device-id> \
  --dart-define=SHOT_LOCALE=zh-CN
# repeat with SHOT_LOCALE=en-US
```

- `SHOT_LOCALE` switches the app UI language AND the seeded data language.
- Captures land in `docs/screenshots/raw/…-zh.png` / `…-en.png`.
- The test injects a fake `DeviceSessionHub` — a real hub would dial the seeded
  (bogus) relay URLs and retry forever, so `pumpAndSettle` never settles.
- After `convertFlutterSurfaceToImage()` the rasterizer keeps scheduling frames;
  the test pumps real time instead of `pumpAndSettle` for pages 2–3.

## Tablet (dual-pane) capture

The `04-dualpane` shot only renders when the device surface is ≥768dp wide.
To capture it on the `zlinker_test` emulator, switch the display profile to an
iPad-Pro-13-like size before driving, then reset afterwards (the profile is
sticky, so the portrait set must be re-captured after switching back):

```bash
adb shell wm size 2752x2064 && adb shell wm density 400
# ... drive both SHOT_LOCALE runs (captures 04-dualpane-{zh,en}) ...
adb shell wm size reset && adb shell wm density reset
# ... re-run both drives to restore the portrait 01–03 set ...
```

## Resize to store sizes

Windows/Linux (Pillow); macOS can use `sips`:

```bash
python - <<'EOF'
from PIL import Image
import os
RAW = 'docs/screenshots/raw'
for name in ['01-devices','02-tasks','03-chat']:
    for lang in ['en','zh']:
        im = Image.open(f'{RAW}/{name}-{lang}.png')
        im.resize((1290,2796), Image.LANCZOS).save(
            f'docs/screenshots/iphone/{name}-{lang}.png')
        im.resize((1080,2400), Image.LANCZOS).save(
            f'docs/screenshots/play/{name}-{lang}.png')
for lang in ['en','zh']:
    im = Image.open(f'{RAW}/04-dualpane-{lang}.png')  # 2752x1914
    r = im.resize((2732, int(im.height * 2732 / im.width)), Image.LANCZOS)
    top = (r.height - 2048) // 2
    r.crop((0, top, 2732, top + 2048)).save(
        f'docs/screenshots/iphone/04-dualpane-{lang}.png')  # iPad 12.9" slot
    im.resize((1920,1200), Image.LANCZOS).save(
        f'docs/screenshots/play/04-dualpane-{lang}.png')    # Play tablet
EOF
```

iPad listing slots stay covered by the framed landscape composites in
`docs/store/appstore/screenshots/ipad-13/`; the raw dual-pane capture here is
the unframed alternative.

Copy text lives in `fastlane/metadata/{zh-Hans,en-US}` and
`docs/store/*/copy/`; feature graphic and Play icon are in
`docs/store/googleplay/`.
