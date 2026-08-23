# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
