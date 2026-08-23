# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-08-23

### Added

- Server-side automations (设备自动化): full CRUD against the desktop
  `zcode-cron-scheduler` — cron / interval+cap / one-shot-delay triggers,
  optional model/mode/thoughtLevel/targetTaskId, enable toggle, edit and
  delete-with-confirm; humanized trigger summaries; unavailable state
  guides to local scheduled messages. Entry from the task-list menu and
  the combined scheduled page (`automation.dart` port with probed method
  names; `listAllAutomations` live-confirmed).
- Off-peak tasks (闲时任务): submit queued runs for compute-rich windows —
  title/prompt/model/earliest/keepAwake/permission form with three quick
  templates, live queue position (#N), pause / resume / cancel, history
  with duration, official error states (仅 Coding Plan 可用 / 额度已用尽 /
  服务暂不可用), quota header, and view-result deep-link into the produced
  session (`off_peak.dart` port + error classification).
- Local notifications (`flutter_local_notifications`): three separately
  silenceable channels (task events / off-peak events / automation
  results), Android 13+ runtime permission asked lazily, tap on a
  notification deep-links to the conversation, master + per-channel
  switches in settings; task events ride the sessions-index stream,
  off-peak (60s) and automation (120s) results poll — pure diff rules in
  `notify_rules.dart`, glue in `notification_hub.dart`.
- Combined scheduling page: 设备自动化 + 本地定时发送 coexisting sections.
- ~58 new tests (automation/off-peak ports with fake channels, pages with
  fake hosts, notification rules + hub glue, settings switches).

## [1.1.0] - 2026-08-23

### Added

- Hybrid architecture: a pure-Dart protocol stack (relay, pairing proof,
  rpc-frame, IPC codec, conversation V4) powers the glanceable layer natively,
  while conversations stay in the official web remote.
- Native device list with live online status and running-task badges.
- Native task list with stop / pause / resume controls.
- Deep-link from a task card into the web remote, opened at that exact task;
  graceful fallback to plain web mode when the protocol shifts.
- Usage stats, device usage, and model providers pages.
- Scheduled tasks store and page.
- Settings, UI settings, and About pages.
- In-app update checker (`package_info_plus` + GitHub Releases).
- ~100 new tests (protocol, stores, settings, update service, deep-link JS).

### Changed

- Android application id / namespace: `org.songsong.zremote`.
- README (EN + zh-CN) rewritten around the hybrid positioning.

## [1.0.1] - 2026-08-23

### Added

- App icon in the official ZCode style: dark `#161616` background, bold
  geometric white "Z", sky-blue broadcast accent; generated for all Android
  densities (classic + adaptive) and iOS via `flutter_launcher_icons`.
- `tool/icon_gen.dart` — regenerates the icon source art from code.

### Changed

- README (English + 简体中文) rewritten: new tagline, no third-party project
  references.

## [1.0.0] - 2026-08-23

### Added

- Device list home: cards with name / host / last-used time; rename, delete,
  copy link, open in browser; device backup export / import (JSON).
- Add devices by camera QR scan, gallery QR decode (pure Dart), or pasting a
  remote-control URL; automatic de-duplication; unparseable URLs are still
  saved with a warning.
- Full-screen in-app WebView remote page (flutter_inappwebview) with loading
  progress bar, reload, and open-in-browser escape hatch; DOM storage
  persists the official page's pairing state.
- Official-theme design system extracted from the real ZCode web-remote
  bundle: Tailwind neutral gray scale + sky accent, dark `#161616` default,
  light and follow-system modes.
- Dark / light / system theme with persistence.
- Android + iOS projects, permissions, and display names configured.
- Unit tests (URL parsing, device store CRUD / persistence / import-export)
  and widget tests (empty state, device card, app boot).
- CI workflow (analyze + test) and release workflow (tag → APK → GitHub
  Release).
