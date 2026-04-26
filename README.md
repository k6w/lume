<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/logo-light.svg">
  <source media="(prefers-color-scheme: light)" srcset="assets/logo.svg">
  <img src="assets/logo.svg" alt="Lume" width="280" />
</picture>

### A clipboard, lit.

A native, Liquid-Glass macOS clipboard manager that lives in your menu bar,
backs up to iCloud, and stays out of your way until you need it.

[Install](#install) · [Features](#features) · [Build from source](#build-from-source) · [Architecture](docs/ARCHITECTURE.md) · [Contributing](docs/CONTRIBUTING.md)

</div>

---

## Why Lume

Most clipboard managers are utilities. Lume is a product. It is built from
day one for **macOS 26 Tahoe** and uses Apple's **Liquid Glass** material
exclusively, so it looks and feels native — not like a window glued onto
your menu bar.

- **One click** opens a glass popover with your full history and a
  search field. No delay.
- **Right-click** the menu-bar glyph for **Open Lume…** and **Settings…**.
- **iCloud-backed by default.** Your clipboard syncs across every Mac
  you own, end-to-end-encrypted for sensitive entries.
- **Superfast.** Cold launch under 120 ms, popover refresh under one
  frame, full-text search at 100k+ rows under 16 ms — enforced by tests
  in CI.
- **Open source. MIT licensed. No telemetry.**

## Features

### Capture
| | |
|---|---|
| **Text + RTF + HTML** | Always on. Plain text + the formatted blob alongside, so you can paste back with formatting if you want. |
| **Colors** | Hex codes (`#7A70FF`) and color-picker output (NSColor) auto-detect into a Color clip. |
| **File paths** | Always on, but **stores only the path** — no file body, so it costs nothing. Stale paths are flagged in the row and pasting falls back to plain text if the file moved. |
| **Images** | Opt-in (Settings → Data → Images). Off by default to keep the database lean. When on, screenshots and copied images land with a 200×200 JPEG thumbnail for fast lists. |
| **Excluded apps** | Tell Lume to never read the clipboard while certain apps are frontmost. |
| **Sensitive content** | Heuristically detected secrets are sealed with **ChaCha20-Poly1305** before they ever touch disk or iCloud. The key lives in iCloud Keychain (E2E by Apple). |

### Find
| | |
|---|---|
| **FTS5 search** | SQLite full-text search. Instant even at 100k rows. |
| **Smart filters** | **URLs**, **Emails**, **Today**, **This Week** — sidebar entries computed via `NSDataDetector` at filter time. |
| **Type filters** | Files, Colors, Images (when capture is on). |
| **Pinned** | Star anything to keep it forever. Pinned clips survive auto-purge. |
| **Per-app filtering** | Source app and bundle id are searchable. |

### Act
| | |
|---|---|
| **Quick paste** | Click a row in the popover, ⌘1–9 in the popover, or double-click in the main window. |
| **Smart actions in detail** | Open URL, Email …, Reveal in Finder — surfaced when the clip's content matches. |
| **Quick transforms** | One-click lowercase / uppercase / trim / JSON pretty-print / base64 ↔ / URL encode-decode. The transformed result is copied **and** added back to history. |
| **Edit mode** | Inline `TextEditor` to fix typos, then Save & Copy without mutating the original. |
| **Plain-text paste** | Strip formatting from any rich-text clip via context menu. |
| **Snippets** | Saved boilerplate with variables: `{{date}}` `{{time}}` `{{datetime}}` `{{clipboard}}`. Insert from a menu in the popover footer or the **Snippets** tab. |
| **Tags** | Manage colored tags in Settings → Tags. Apply/remove from the detail pane. |
| **Global hotkey** | Default ⌥⌘V to summon the popover from anywhere. Configurable in v0.2. |

### Live with it
| | |
|---|---|
| **Per-kind auto-purge** | Independent retention windows for text/colors (default 30 d), images (7 d), files (14 d). Pinned clips never purge. |
| **iCloud sync** | Backup and sync via your private CloudKit container. Lume has no servers. Disabled gracefully when there's no iCloud entitlement. |
| **Bulk maintenance** | Settings → Data → **Compact database (VACUUM)** and **Clear all unpinned** with a confirmation alert. |
| **Stats** | Per-day capture chart for the last 30 days (Swift Charts), top apps with their icons, top kinds, storage used. |
| **Onboarding** | Four-step welcome on first launch. |
| **Native macOS** | `NSStatusItem`, `NSSearchField`, `List(selection:)`, `Form` — built with the system's components, not custom skins. |

## Install

Lume is distributed as an unsigned `.dmg` and `.zip` from
[GitHub Releases](https://github.com/k6w/lume/releases). It is not
on the Mac App Store and is not signed with a Developer ID — this is an
intentional choice to keep the project free, open, and frictionless to
ship.

The first launch needs one of these two steps to satisfy Gatekeeper:

```sh
# Option A — strip the quarantine flag
xattr -dr com.apple.quarantine /Applications/Lume.app
```

```text
Option B — right-click the app, choose "Open", then click "Open" in the
warning dialog. After the first launch, double-click works normally.
```

System requirements:

- macOS 26 Tahoe or later
- Apple silicon (Universal binary planned)

## Build from source

```sh
git clone https://github.com/k6w/lume.git
cd lume
brew install xcodegen
./scripts/run.sh           # builds + launches
```

The convenience script:

```text
./scripts/run.sh           # build + launch (default)
./scripts/run.sh build     # just build
./scripts/run.sh test      # run the unit tests
./scripts/run.sh bench     # run perf benchmarks
./scripts/run.sh kill      # stop a running Lume
./scripts/run.sh regen     # regenerate Lume.xcodeproj from project.yml
```

GRDB is the only runtime dependency. Open `Lume/Lume.xcodeproj` in
Xcode 26 if you prefer the IDE. Configurations check in:

- **Local debug** — entitlements stripped of iCloud / APS so you don't
  need an Apple Developer team. iCloud sync is auto-disabled at
  runtime when the entitlement is missing.
- **Release** — uses the full `Lume.entitlements` (CloudKit, APS,
  Keychain group). You'd need a paid Apple Developer team to ship
  signed builds, but the unsigned local build is fully usable.

To cut a release artifact:

```sh
./scripts/release.sh 0.1.0
```

Produces `dist/Lume-0.1.0.zip`, `dist/Lume-0.1.0.dmg`, and a
matching `SHA256SUMS`.

## Privacy

Lume reads `NSPasteboard.general` whenever it changes, on a 0.4 s timer.
Nothing leaves your machine unless **iCloud Sync** is enabled, in which
case the only network destination is your own private CloudKit
database. Lume has no telemetry, no analytics, and no remote config.

You can exclude any app from monitoring under **Settings → Privacy**.

## License

[MIT](LICENSE) — do whatever you want, just keep the notice.
