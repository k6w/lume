# Changelog

All notable changes to Lume are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added — v0.2 work

#### Smart filters
- New **URLs** sidebar entry, computed at filter time via
  `NSDataDetector` (`.link` minus `mailto:`).
- New **Emails** entry — `NSDataDetector` is too eager (it returns
  emails as `mailto:` links), so we use a tight regex.
- New **Today** and **This Week** date-bucketed filters.

#### Quick transforms
- One-click **lowercase**, **uppercase**, **trim**, **JSON pretty**,
  **base64 encode/decode**, **URL encode/decode** in the detail pane.
  Each transform is gated on `applies(to:)` so the chip only appears
  when meaningful (e.g. JSON pretty hides if the text doesn't start with
  `{` or `[`). The transformed result is copied **and** persisted back
  to history.

#### Tags
- New `TagRepository` with full CRUD + clip-tag link CRUD.
- **Settings → Tags** pane to add/rename/delete tags and pick colors.
- Tag chips in the detail pane with an **Add Tag** menu listing
  unassigned tags.
- Foreign-key cascade cleans up `clip_tag` rows when a tag is deleted.

#### Snippets
- Monospace `TextEditor` with optional shortcut field.
- New `SnippetExpander` for `{{date}}` `{{time}}` `{{datetime}}`
  `{{clipboard}}` variables.
- **Snippets** sub-menu in the popover footer for paste-without-
  opening-main.
- ⌘N shortcut opens new-snippet sheet.

#### Detail pane
- **Inline edit mode**: TextEditor + Save & Copy, persists as a new
  history entry rather than mutating the original.
- **Smart actions**: Open URL · Email · Reveal in Finder, surfaced
  when the clip content matches.
- **Text stats**: chars · words · lines.
- **Source-app icon**: resolved from bundle id via `NSWorkspace`,
  cached, surfaced in row meta and the metadata block.
- **File staleness banner**: a warning marker in row meta + a banner
  in the detail pane when any path in a file clip has moved or been
  deleted.

#### Capture
- File clips: only the path string is stored — no file body.
- File paste: `PasteInjector` writes file URLs only for paths that still
  exist; falls back to plain text otherwise.
- Per-kind capture toggle: **Images** opt-in (default off) under
  Settings → Data. The Sidebar's **Images** filter only shows when on.
- **Per-kind retention windows**: text/colors (default 30 d), images
  (7 d), files (14 d). `PurgeScheduler` reads `CaptureSettings`
  every tick.

#### UI
- Toolbar **hoisted to MainWindow** with **Copy** + native
  `NSSearchField` at `.navigation` placement. Identical on every tab —
  no more height jumps when switching between History and Settings.
- **`NSSearchField` via `NSViewRepresentable`** instead of `.searchable`
  (which caused the toolbar to grow/shrink).
- **Capture toast** (subtle in-popover flash when something new lands).
- ⌘1–9 quick-paste in popover; arrow-key nav already in place.
- ⌘ , in the menu-bar context menu.
- New `EmptyStateView` with per-scope nudges.
- New `AppIconView` (async, cached) for source app icons.
- New `ThumbView` (off-main image decode + cached `Image`) so image-
  heavy lists don't lag.

#### Stats
- **Swift Charts** per-day capture chart for last 30 days.
- Storage tile (sum of `byteSize`).
- Top apps with their resolved icons.

#### Bulk ops
- **Compact database (VACUUM)** in Settings → Data.
- **Clear all unpinned clips** with native confirmation alert.

#### Tests
- 29 unit tests pass. New suites: `TextDetectorTests`,
  `SnippetExpanderTests`, `TagRepositoryTests`, `PerKindRetentionTests`,
  `FileStalenessTests`.

### Changed
- **Click model**: instant. Single click opens the popover with no
  delay. The previous "delayed discrimination" double-click model is
  gone — main window opens via popover footer or right-click menu.
- **Code as a separate kind**: removed from the sidebar. Code-looking
  text is now indistinguishable from text in the UI; the enum case
  remains for forward compat.
- `AppDatabase.inMemory()` uses a per-test temp file (DatabasePool can't
  enable WAL on `:memory:`).
- Sensitivity entropy threshold lowered from 4.5 → 4.0 (= log₂(16)) so
  16-char generated secrets cross the line.
- Settings switched from a custom segmented Picker / nested
  `NavigationSplitView` to a clean **`HSplitView` + sidebar
  `List(selection:)`** to fix the Settings-was-empty regression.

### Fixed
- `CKContainer(identifier:)` traps when the iCloud entitlement is
  missing — sync engine now defers container creation and short-
  circuits gracefully on local builds without an Apple Developer team.
- `readObjects(forClasses: [NSURL.self]) as? [URL]` cast was
  unreliable; replaced with explicit `NSURL → URL` bridging via
  `compactMap`.
- `Timer` callbacks into `@MainActor` methods now wrap in
  `Task { @MainActor in ... }`.
- Tests target now generates its Info.plist via project config
  (`GENERATE_INFOPLIST_FILE: YES`).

## [0.1.0] — 2026-04-26

### Added
- Initial scaffolding: branding, Xcode project, persistence, services,
  Liquid Glass UI, onboarding, CloudKit sync wiring, performance
  budgets and tests.

[Unreleased]: https://github.com/k6w/lume/compare/v0.1.0...HEAD
[0.1.0]:      https://github.com/k6w/lume/releases/tag/v0.1.0
