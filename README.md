<div align="center">

# ZRemote

**zemote, without the protocol.**

The open-source, protocol-proof remote launcher for **ZCode** —
manage your desktop devices in one list, tap one, and you're in the official
web remote. No relay handshake, no pairing proofs, no IPC to track.

[简体中文](README.zh-CN.md) · [Why ZRemote?](#-why-zremote) · [Features](#-features) · [Compare](#️-zremote-vs-zemote) · [Quick Start](#-quick-start) · [Architecture](#-architecture) · [Roadmap](#️-roadmap)

[![Release](https://img.shields.io/github/v/release/opensymph/ZRemote?style=flat-square&logo=github&color=blue)](https://github.com/opensymph/ZRemote/releases)
[![Build](https://img.shields.io/github/actions/workflow/status/opensymph/ZRemote/ci.yml?style=flat-square&label=build)](https://github.com/opensymph/ZRemote/actions/workflows/ci.yml)
[![Stars](https://img.shields.io/github/stars/opensymph/ZRemote?style=flat-square&color=yellow)](https://github.com/opensymph/ZRemote/stargazers)
[![Forks](https://img.shields.io/github/forks/opensymph/ZRemote?style=flat-square&color=orange)](https://github.com/opensymph/ZRemote/forks)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey?style=flat-square)](#-quick-start)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.44%2B-blue?style=flat-square&logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12%2B-0175C2?style=flat-square&logo=dart)](https://dart.dev)

</div>

---

## 💡 Why ZRemote?

[zemote](https://github.com/HumanAILoop/zemote) proved a third-party ZCode
remote client was possible — by re-implementing the entire private protocol:
relay handshake, HMAC-SHA256 pairing proofs, rpc-frame fragmentation, IPC
codec, and the V4 snapshot/delta protocol.

It's an impressive piece of reverse engineering. It's also a treadmill:
every time Zhipu tweaks the protocol, a protocol client breaks until someone
re-ports it.

**ZRemote takes the opposite bet: implement none of it.** It is a launcher —
a clean device list plus an embedded browser that opens the *official* web
remote page. Zhipu owns the protocol, updates it, and ships it; ZRemote just
points at it.

- 🧬 **Protocol-upgrade immune** — Zhipu ships remote v5 tomorrow? Scan the
  new QR code. The app is unchanged.
- 🪶 **~1,000 lines of Dart** — nine files, three of them UI. Nothing to
  bit-rot.
- 📋 **A list done right** — scan / paste / gallery-decode to add,
  rename / delete / copy / backup; sorted by what matters: your devices.
- 🌐 **The official experience, always current** — the real web remote in a
  fullscreen WebView, pairing state persisted between sessions.
- 🎨 **Pixel-official theme** — design tokens extracted from the actual web
  bundle (neutral grays + sky accent, `#161616` dark). It looks like it
  belongs.
- 🔐 **Credentials stay on your phone** — device URLs live in local storage
  only; no servers, no telemetry, no accounts.

> *If zemote is the power user's client, ZRemote is the one that never breaks.*

Sounds good? **Star ⭐ the repo** to follow along.

---

## ✨ Features

| | |
|---|---|
| 📋 **Device list** | Cards with device name, host, and last-used time; rename, delete, copy link, open in browser; export / import your device backup as JSON |
| ➕ **Add by scan, paste, or screenshot** | Camera QR scan (`mobile_scanner`), pure-Dart gallery QR decode (`zxing2`), or paste a URL — with de-duplication; unparseable links are still saved, never lost |
| 🌐 **In-app web remote** | Fullscreen `flutter_inappwebview` with a loading progress bar, reload, and an "open in browser" escape hatch; DOM storage keeps the official page's pairing across opens |
| 🎨 **Official design tokens** | Neutral gray scale + sky accent extracted from the real bundle; dark `#161616` default, light, and follow-system themes |
| 🌗 **Theme control** | Dark / light / system, persisted — dark by default, just like the official page |
| 📱 **Android + iOS** | One codebase, both platforms, permissions pre-wired (camera, photo library) |

---

## ⚔️ ZRemote vs zemote

Honest comparison — pick the right tool. zemote is a great project and worth
a star too.

| | **ZRemote** | **[zemote](https://github.com/HumanAILoop/zemote)** |
|---|---|---|
| Approach | URL launcher + official web remote | Full protocol re-implementation |
| Survives Zhipu protocol changes | ✅ re-scan once, app unchanged | ⚠️ needs a protocol-layer update |
| Remote UI | Official web page (always current) | Native re-implementation |
| Native chat / streaming UI | ❌ via the web page | ✅ native |
| Background / push notifications | ❌ | ✅ Android |
| Multi-device management | ✅ list + JSON backup | ✅ list + live connection status |
| Code to maintain | ~1k LoC, no protocol | relay + rpc-frame + IPC + V4 stack |
| Offline pairing state | Persisted WebView storage | Native pairing |
| Android | ✅ | ✅ |
| iOS | ✅ build on a Mac | ⚠️ unverified |

---

## 📸 Screenshots

Coming with the first tagged release. Want to help capture them? See
[Contributing](#-contributing).

---

## 🚀 Quick Start

You need a desktop machine running **ZCode** (zcode.z.ai). Generate a remote
link there: ZCode → Remote Control → QR code / copy link. It looks like:

```text
https://zcode.z.ai/remote/v4?sid=...&hash=...&t=...&mid=...&name=...
```

### Option A · Download a prebuilt APK

Grab the latest APK from
[Releases](https://github.com/opensymph/ZRemote/releases), install it on your
phone, and add your first device by scanning the QR code.

> ⚠️ Only install APKs from a Release you trust — a remote-control link is a
> device credential. Audit the code, or build it yourself (Option B).

### Option B · Build from source

Prerequisites: [Flutter](https://docs.flutter.dev/get-started/install) 3.44+
(Dart 3.12+). For Android builds: JDK 17 + Android SDK. For iOS: a Mac with
Xcode.

```bash
git clone https://github.com/opensymph/ZRemote.git
cd ZRemote
flutter pub get

flutter run                       # debug on a connected device
flutter build apk                 # → build/app/outputs/flutter-apk/app-release.apk
flutter build ipa                 # on a Mac, after configuring signing
```

Inside the app: **添加设备 (Add device)** → scan or paste → tap the card →
you're in.

---

## 🧱 Architecture

```
┌─────────────────────────────────────────────────┐
│ UI (lib/ui)                                     │
│   devices_page · remote_page · qr_scan_page     │
├─────────────────────────────────────────────────┤
│ State (lib/state)                               │
│   device_store — SharedPreferences JSON         │
├─────────────────────────────────────────────────┤
│ Core (lib/core)                                 │
│   connection_params — URL → device label only   │
└───────────────┬─────────────────────────────────┘
                │ opens the URL
┌───────────────▼─────────────────────────────────┐
│ Official ZCode Web Remote (in a WebView)        │
│   relay · pairing · IPC · V4                    │
│   — owned and updated by Zhipu, not by us       │
└─────────────────────────────────────────────────┘
```

```text
lib/
├── main.dart                  # entry: theme + home
├── core/
│   ├── connection_params.dart # remote URL parsing (label only, no protocol)
│   └── id.dart                # UUID
├── state/
│   └── device_store.dart      # device model + persistence + import/export
└── ui/
    ├── theme.dart             # official design tokens + dark/light themes
    ├── devices_page.dart      # the device list
    ├── qr_scan_page.dart      # camera + gallery QR scanning
    └── remote_page.dart       # fullscreen WebView remote
```

---

## 🗺️ Roadmap

- [ ] Screenshots + demo GIF in the README
- [ ] Clipboard detection — offer to add when a remote URL is copied
- [ ] Drag-to-reorder and pin devices
- [ ] Per-device `theme=dark|light` URL parameter
- [ ] Home-screen quick-open widget (Android)
- [ ] iOS artifacts in the release workflow
- [ ] English localization

---

## 🤝 Contributing

Issues and PRs are welcome. Before submitting:

```bash
flutter analyze   # zero warnings
flutter test      # all green
```

Small, focused PRs land fastest. For UI work, keep the
[official design tokens](lib/ui/theme.dart) — that's the point.

---

## 🙏 Acknowledgements

- **[zemote](https://github.com/HumanAILoop/zemote)** — the reference project
  this repo learned from; its URL parser, QR flow, and storage pattern were
  adapted here. MIT.
- **ZCode & the official web remote** — the actual remote experience; all
  protocol smarts live there.
- The Flutter ecosystem: `flutter_inappwebview`, `mobile_scanner`, `zxing2`,
  `shared_preferences`, `url_launcher`.

> ⚠️ ZRemote is an independent, community tool. It is not affiliated with,
> endorsed by, or connected to Zhipu AI. Use it only with devices you own and
> in accordance with the ZCode terms of service.

---

## License

MIT © ZRemote contributors — see [LICENSE](LICENSE).
