# Store screenshots

Local tool (not in CI): captures the real pages with seeded fake data
(devices / task list / conversation) on any connected device or simulator.

```bash
flutter test integration_test/screenshots_test.dart -d <device-id> \
    --screenshots build/screenshots
```

Resize to store sizes afterwards (example, macOS sips):

```bash
sips -z 2796 1290 build/screenshots/01-devices.png --out store/screens/01-devices_iphone69.png
sips -z 1920 1080 build/screenshots/01-devices.png --out store/screens/01-devices_play.png
```

Copy text lives in `fastlane/metadata/{zh-Hans,en-US}`; feature graphic
and Play icon are in `store/`.
