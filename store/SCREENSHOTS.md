# Store screenshots

Automated: Actions → Release workflow → "Store screenshots" job
(workflow_dispatch only) — boots an iPhone simulator, runs
`integration_test/screenshots_test.dart` with seeded fake data
(devices / task list / conversation), then resizes captures into
`store/screens/` (App Store 6.9" 1290x2796 + Play 1080x1920).

Manual run on any connected device:

```bash
flutter test integration_test/screenshots_test.dart -d <device-id> \
    --screenshots build/screenshots
```

Copy text lives in `fastlane/metadata/{zh-Hans,en-US}`; feature graphic
and Play icon are generated in `store/`.
