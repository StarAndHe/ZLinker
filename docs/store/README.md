# Store materials

Ready-to-upload listing assets (图片物料 + 文案物料) for **ZLinker**
(`org.songsong.zlinker`) on the App Store and Google Play. Both stores get
bilingual copy (English `en-US` + 简体中文 `zh-Hans`) and matching graphics.

All graphics are generated from the real app art and screenshots by
[`tool/gen_store_assets.py`](../../tool/gen_store_assets.py) so they stay
on-brand (dark `#161616`, slate ring, sky `#38BDF8`, white `Z_` glyph).

## Layout

```
docs/store/
├── appstore/
│   ├── copy/            en-US.md · zh-Hans.md   (name, subtitle, promo,
│   │                                             description, keywords, what's new)
│   ├── icon/            app-icon-1024.png       1024×1024, no alpha
│   └── screenshots/
│       ├── iphone-6.9/  1290×2796  hero · tasks · conversation · features (en+zh)
│       └── ipad-13/     2752×2064  dual-pane (en+zh)
└── googleplay/
    ├── copy/            en-US.md · zh-Hans.md   (title, short + full description,
    │                                             release notes)
    ├── icon/            play-icon-512.png       512×512
    ├── feature-graphic/ 1024×500  (en+zh)       required Play banner
    └── screenshots/
        ├── phone/       1080×2400  hero · tasks · conversation · features (en+zh)
        └── tablet/      1920×1200  dual-pane (en+zh)
```

## Store specs these assets satisfy

### App Store Connect
| Asset | Size | Notes |
| --- | --- | --- |
| App icon | 1024×1024 | PNG, no alpha/transparency (Apple rounds it) |
| iPhone 6.9" screenshots | 1290×2796 | Covers the required 6.9"/6.7" slot |
| iPad 13" screenshots | 2752×2064 | Landscape; optional but recommended |

### Google Play Console
| Asset | Size | Notes |
| --- | --- | --- |
| App icon | 512×512 | 32-bit PNG |
| Feature graphic | 1024×500 | Required |
| Phone screenshots | 1080×2400 | 2–8 per language; min 320px, 16:9-ish |
| Tablet screenshots | 1920×1200 | Landscape; recommended for tablet listing |

> App Store lets you inherit the 6.9" set for smaller iPhones, so a single
> 1290×2796 set is enough to publish.

## Copy

Editable Markdown with character counts against each store's field limits:

- App Store — [`appstore/copy/en-US.md`](appstore/copy/en-US.md) · [`appstore/copy/zh-Hans.md`](appstore/copy/zh-Hans.md)
- Google Play — [`googleplay/copy/en-US.md`](googleplay/copy/en-US.md) · [`googleplay/copy/zh-Hans.md`](googleplay/copy/zh-Hans.md)

The canonical fastlane submission text still lives in
[`fastlane/metadata/`](../../fastlane/metadata); these files are the
human-facing, annotated versions with per-field character counts.

## Regenerate the graphics

```bash
pip install Pillow
python3 tool/gen_store_assets.py
```

Source inputs:

- `assets/icon/icon.png` — 1024 app icon (from `tool/icon_gen.dart`)
- `docs/screenshots/raw/02-tasks-en.png`, `03-chat-en.png`, `04-dualpane-en.png`
  — real captures from `integration_test/screenshots_test.dart` (seeded data)

To refresh the underlying screenshots with new seeded data, recapture them
per [`docs/store/SCREENSHOTS.md`](SCREENSHOTS.md) — they land directly in
`docs/screenshots/raw/`, then rerun the generator.

## Notes

- The device-frame captions are marketing overlays. If a store rejects
  framed/annotated screenshots for a given slot, upload the unframed captures
  in `docs/screenshots/` instead (`iphone/` + `play/` are already at store
  sizes).
- ZLinker is an independent community tool, not affiliated with Zhipu AI.
  Keep that disclaimer in the store description (already included in the copy).
