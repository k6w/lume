# Changelog

All notable changes to Lume are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] — 2026-04-28

### Fixed
- **Captures-per-day chart was always empty.** GRDB stored `Date` as
  ISO-8601 TEXT in a REAL-affinity column, so the SQL did
  `lastSeenAt - cutoff` numeric arithmetic and `WHERE lastSeenAt >=
  numericCutoff` — both filtered every row. Bucket via SQLite
  `date(lastSeenAt, 'localtime')` keyed by `yyyy-MM-dd` instead.
- **"Launch at login" toggle did nothing.** Wired to
  `SMAppService.mainApp` via a new `LaunchAtLogin` helper, with
  re-sync on appear so System Settings changes don't leave the toggle
  stale.
- **"Show Lume in the Dock" toggle did nothing.** Now applied at boot
  in `AppDelegate` and on toggle change via
  `NSApp.setActivationPolicy`.
- **"Always paste as plain text" toggle did nothing.**
  `PasteInjector.copy` now reads the setting and routes
  text/code/rtf/html through `copyAsPlainText`.
- **"Encrypt clips that look like secrets" toggle did nothing.**
  `PasteboardWatcher` now respects the toggle, and the default is
  flipped to **off** so secret-shaped clips are not silently sealed
  when the user has not opted in.
- **Encrypted clips were silently invisible and unpasteable.**
  `EncryptionService.open` was never called. Decrypt at the
  observation boundary in `HistoryBrowser` and `PopoverRoot`, and
  decrypt inside `PasteInjector.copy/copyAsPlainText` so paste-back
  works for clips reached via `clipRepository.clip(id:)`.
- **Menu-bar icon stuck on the pause glyph at boot.** `install()`
  read `pasteboardWatcher.isCapturing` before
  `bootBackgroundServices` had a chance to start the watcher, so
  every launch looked paused. Default to the running glyph at
  install; runtime Pause/Resume still refreshes.
- **"Last synced" row in Data & iCloud was static.** `CloudSyncEngine`
  is `@Observable`; the row reads `cloud.lastSyncedAt` directly so it
  updates the moment a sync pass completes.
- **Pinning didn't bump `lastSeenAt`.** A freshly-pinned clip stayed
  buried in the pinned section. Now floats to the top.
- **`CloudSyncEngine.flushDeletes` cleared tombstones unconditionally.**
  A transient network blip used to drop the local tombstone while the
  CloudKit row remained. Only clear for IDs the server confirmed
  gone (or already missing).

### Added
- **Image thumbnails in the popover.** Minimal style now shows an
  inline 32×18 thumbnail for image clips instead of a generic photo
  glyph plus "Image · 247 KB" text. The byte size moves to the
  hover/highlight meta line next to the relative time, hit count,
  and source app.
- **Visible Pause Capture state.** Menu-bar glyph swaps to
  `pause.circle` while capture is paused. The right-click menu also
  greys out the inactive of Pause/Resume.
- **Color retention stepper.** `retentionColors` was already plumbed
  through the purge scheduler; DataPane now actually exposes it.

### Changed
- `excludedAppCache` is annotated `@MainActor` — both its reader
  (`tick`) and its writer (`PrivacyPane`) already lived there;
  Swift 6 strict concurrency stops guessing.

## [0.3.1] — 2026-04-26

### Fixed
- **Sidebar arrow-key navigation** — restored after dropping
  `List(selection:)`. Implemented by hand with `@FocusState` +
  `.onKeyPress(.upArrow/.downArrow)` walking the visible items.
- **Main-window clip list** had the same double-highlight as the
  sidebar (system selection rect ignoring our tint). Same fix —
  custom Button rows + accent `.listRowBackground`. Arrow-key
  navigation reimplemented with auto-scroll via `ScrollViewReader`.
- **Sidebar text contrast**: selected row's text stays `.primary`
  with semibold weight; only the icon picks up the accent. The
  text was washing out against the accent-tinted backdrop.

## [0.3.0] — 2026-04-26

### Fixed
- **Sidebar selection** now wears the user's accent. macOS's
  `List(.sidebar)` ignores SwiftUI's `.tint` and draws selection with
  `NSColor.controlAccentColor`. We replace the native rectangle via
  `.listRowBackground` per row.
- **Onboarding bottom overlap**: removed the redundant "Six quick
  screens" footer from WelcomeStep and added 12/14 pt of breathing
  room around the step-indicator capsules.
- **Native control tinting**: `.tint(accent)` applied at every window
  root so toggles, segmented pickers, prominent buttons, sliders,
  search-field clear button, and the indicator capsules pick up the
  custom accent.
- **Updates tab showed v0.1**: `MARKETING_VERSION` bumped to 0.3.0.

### Added
- **Custom hotkey recorder** in Settings → Hot Keys. Click the recorder,
  press the chord; the new shortcut is registered globally and persisted
  to UserDefaults as JSON. Reset button falls back to ⌥⌘V.
- **Seven-step onboarding** (was four): Welcome, Capture, Find, Tags,
  Snippets, Hot key (live recorder), Done. Each step has a glass demo
  card showing what the feature actually looks like in the app, the
  step indicator animates the active capsule, and Skip is now offered
  on the first screen for power users who already know the drill.
- **Tag filter in toolbar** (`.navigation` placement): All Tags /
  Untagged / per-tag, each rendered with its own SF Symbol and color.
  Composes with the sidebar scope and the search query.
- **Update banner X button** dismisses per-version instantly (was
  silent). `UpdateChecker.dismissedVersion` is now a tracked stored
  property mirrored to UserDefaults.
- **Real macOS app icon**: `assets/app-icon.svg` is a white squircle
  with a deep ink L and a single indigo spark. `scripts/generate-icons.sh`
  rasterises every macOS slot via `rsvg-convert`. The next .dmg ships
  with a proper Lume icon.
- **Tag editor sheet** with a curated ~80-icon SF Symbol grid, color
  picker, and a header preview that updates as you pick. Migration v2
  adds `tag.icon`. The detail-pane "Add Tag" menu now has a "New Tag…"
  entry so creating + applying happens in one click.
- **Popover style** preference (Settings → General): **Default** is
  the two-line row; **Minimal** is single-line with the source-app icon
  on the right and meta + pin revealed on hover.
- **Inline transforms**: lowercase / uppercase / trim / JSON pretty /
  base64 ↔ / URL ↔ now show their result in a card under the body
  with **Copy** + **Dismiss**, instead of creating a new history
  entry. Result card uses monospace for JSON/base64.
- **Smart filters**: URLs / Emails / Today / This Week sidebar entries.
- **Snippets** — variables (`{{date}}`, `{{time}}`, `{{datetime}}`,
  `{{clipboard}}`); monospace editor; visible Edit/Delete on hover;
  popover footer Snippets sub-menu; live observation across the app.

### Changed
- **Theme propagation**: switched from `@Observable LumeTheme` +
  `@Environment` (which didn't reliably cross between independent
  `NSHostingController`s) to a `@LumeAccent` property wrapper backed by
  `@AppStorage`. UserDefaults broadcasts process-wide, so the popover,
  main window, settings, and onboarding all repaint the moment the
  picker fires. The static `LumeTheme.accent` setter still works for
  AppKit code (e.g. the Reset button).
- **Main window is view-only**. Removed double-click-paste; the toolbar
  Copy and the detail-pane Copy stay as the only explicit ways to
  put a clip back on the pasteboard. Right-click context menu loses
  Paste.
- **Self-recapture suppressed**: `PasteInjector.ownedChangeCount`
  records every write; `PasteboardWatcher.tick` skips ticks Lume
  itself caused. Pasting from the popover no longer bumps `hitCount`
  or resets `lastSeenAt` for the clip you just clicked.
- **Click model**: instant single-click in the popover. Removed the
  delayed-discrimination double-click that introduced perceived lag.
  Main window opens via popover footer or right-click menu.
- **Settings layout**: replaced the broken nested `NavigationSplitView`
  with `HSplitView` + native sidebar `List(selection:)`. Tabs render
  at full size on every screen.
- **Per-kind retention**: text/colors (default 30 d), images (7 d),
  files (14 d). Configurable in Settings → Data.
- **Image capture is opt-in**. File-path captures store only the path
  string; stale paths flagged inline; paste falls back to plain text
  if the file moved.
- **Settings tabs**: General / Privacy / Tags / Hot Keys / Data & iCloud
  via plain `List(selection:)` + `Form`.
- **Top margin** under the popover divider so the first row no longer
  kisses the search field.

### Fixed
- `CKContainer(identifier:)` traps when the iCloud entitlement is
  missing — sync engine defers container creation and short-circuits
  gracefully on local builds without an Apple Developer team.
- `readObjects(forClasses: [NSURL.self]) as? [URL]` cast was
  unreliable; replaced with explicit `NSURL → URL` bridging.
- Color-picker change didn't propagate across views.
- `Purge now` was silent — now reports the row count via a native
  `NSAlert` and runs `VACUUM` afterwards.
- Snippets created in the main window didn't appear in the popover
  Snippets menu (now driven by `ValueObservation`).
- AppIcon set was empty, so the .dmg shipped with a blank tile.

## [0.2.0] — 2026-04-26

First public release. See the release notes for what shipped in v0.2
versus what's queued for later.

[Unreleased]: https://github.com/k6w/lume/compare/v0.3.1...HEAD
[0.3.1]:      https://github.com/k6w/lume/releases/tag/v0.3.1
[0.3.0]:      https://github.com/k6w/lume/releases/tag/v0.3.0
[0.2.0]:      https://github.com/k6w/lume/releases/tag/v0.2.0
