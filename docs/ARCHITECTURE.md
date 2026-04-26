# Lume Architecture

## High-level

```
┌────────────────────────────── Lume.app ──────────────────────────────┐
│                                                                       │
│  AppKit shell                                                         │
│   ├─ NSStatusItem ──► MenuBarController (instant click)               │
│   ├─ NSPopover    ──► PopoverRoot (SwiftUI, GlassEffectContainer)     │
│   └─ NSWindow     ──► MainWindowRoot / OnboardingWindow               │
│                                                                       │
│  Services (actors / singletons)                                       │
│   ├─ PasteboardWatcher  (0.4 s changeCount poll, opt-in image kind)   │
│   ├─ HotKeyService      (Carbon RegisterEventHotKey)                  │
│   ├─ PasteInjector      (NSPasteboard + CGEvent ⌘V; file fallback)    │
│   ├─ EncryptionService  (CryptoKit + Keychain, sync-via-Keychain)     │
│   ├─ SensitivityDetector(entropy + bundle-ID heuristic)               │
│   ├─ PurgeScheduler     (per-kind cutoffs from CaptureSettings)       │
│   ├─ CloudSyncEngine    (CloudKit private DB; entitlement-gated)      │
│   ├─ SnippetExpander    ({{date}} / {{time}} / {{clipboard}} …)       │
│   ├─ CaptureSettings    (toggles + retention windows)                 │
│   └─ TextDetector       (NSDataDetector + transforms)                 │
│                                                                       │
│  Persistence                                                          │
│   ├─ Database            GRDB DatabasePool (1 writer, 4 readers)      │
│   ├─ Migrations          schema v1 → ...                              │
│   ├─ ClipRepository      CRUD + dedup + per-kind purge + VACUUM       │
│   ├─ FullTextSearch      FTS5 query layer + triggers                  │
│   ├─ SnippetRepository                                                │
│   ├─ TagRepository       tag + clip_tag CRUD with cascading deletes   │
│   └─ sync_state (local-only)                                          │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
                         iCloud (private CloudKit DB)
                          • zone: Clips
                          • CKRecord per clip, payload as CKAsset > 1MB
                          • encrypted clips ship as ciphertext
                          • encryption key in Keychain (kSecAttrSynchronizable)
```

## Data flow: a copy

1. User presses ⌘C in some app.
2. macOS bumps `NSPasteboard.general.changeCount`.
3. `PasteboardWatcher` notices on the next 0.4 s tick.
4. Walks pasteboard in priority order — file URLs → NSColor →
   image (if `CaptureSettings.captureImages` is on) → text. RTF and
   HTML representations come along with text in the same row.
5. Skips if the frontmost app's bundle ID is in `excluded_app`.
6. Hashes content (SHA-256 over normalized blob).
7. `ClipRepository.upsert(clip)`:
   - If `contentHash` exists → `UPDATE clip SET lastSeenAt = ?, hitCount = hitCount + 1`.
   - Else → `INSERT INTO clip ...` and the FTS5 trigger indexes it.
8. `sync_state.pendingOp = 1` for that clipID.
9. UI is refreshed by GRDB `ValueObservation` (popover + main window).
   The popover shows a brief **"Captured"** toast.
10. On the next sync tick, `CloudSyncEngine` flushes the outbox to
    CloudKit. UI did not wait for the network at any point.

## Data flow: a remote update

1. APNs delivers a silent push to the app process.
2. `CloudSyncEngine` runs `CKFetchRecordZoneChangesOperation` since the
   stored change token.
3. Per remote record:
   - Map `CKRecord` → `Clip` via `ClipRecordMapper`.
   - Resolve conflicts via `ConflictResolver` (LWW on `lastSeenAt`,
     max on `hitCount`, OR on `isPinned`).
   - Upsert into local GRDB.
4. `meta.cloudKit.changeToken` is updated.
5. UI re-renders via `ValueObservation`.

## Smart filters

The sidebar's **URLs**, **Emails**, **Today**, **This Week** entries
are *computed at filter time*, not stored as columns. `TextDetector`
wraps a singleton `NSDataDetector(.link)` and a tight email regex; the
filter just walks the in-memory `[Clip]` and tests each row. Cheap
because the popover/main-window observation already caps at 50/200
rows.

## Concurrency model

- **Main actor**: AppKit shell, SwiftUI views, `MenuBarController`'s
  click logic.
- **Off-main**: `Task.detached` for DB writes, sync engine network
  traffic, encryption, image decoding (`ThumbView` decodes thumbnails
  off-main and caches the `Image`).
- **GRDB**: writer is serial; readers (4) are independent. Reads never
  block writes and vice versa.
- **No Combine on hot paths**: GRDB `ValueObservation` directly drives
  `@Observable` view models.

## Per-kind retention

Each clip kind has its own retention window read from
`CaptureSettings`:

| Kind | Default | Configurable in |
|---|---|---|
| `.text` / `.rtf` / `.html` / `.code` | 30 days | Settings → Data |
| `.color` | 90 days | Settings → Data |
| `.image` | 7 days (only when capture enabled) | Settings → Data |
| `.file` | 14 days | Settings → Data |

`PurgeScheduler` runs every 60 minutes and on launch, computing
per-kind cutoffs and calling
`ClipRepository.purge(perKindCutoffs:)`. Pinned clips never purge.

## Performance budgets (enforced by tests)

See `LumeBenchmarks` target. Budgets:

| Surface | Budget |
|---|---|
| Cold launch → menu-bar icon | < 120 ms |
| First popover open | < 80 ms |
| Popover refresh after copy | < 16 ms (8 ms on ProMotion) |
| FTS query (10k rows) | < 5 ms |
| FTS query (100k rows) | < 16 ms |
| Dedup write | < 3 ms |
| Idle CPU | < 0.1% |
| Memory (typical) | < 80 MB |
| Memory (hard ceiling) | < 150 MB |

CI fails any benchmark that regresses by > 10 %.

## Why GRDB and not SwiftData?

- We need real **FTS5** (SwiftData has no full-text index).
- We need a **unique index** on `contentHash` for dedup; SwiftData
  forbids unique constraints in CloudKit-backed stores.
- GRDB's pool model is faster for this workload.
- We accept the cost: CloudKit sync is custom (one engine, four files)
  rather than free.

## File layout

```
Lume/Lume/
  App/                   ← LumeApp, AppDelegate, AppEnvironment
  Models/                ← Clip, ClipKind, Tag, Snippet, Rule, ContentHasher
  Persistence/           ← Database, Migrations, ClipRepository,
                           SnippetRepository, TagRepository, FullTextSearch
  Services/              ← PasteboardWatcher, MenuBarController,
                           HotKeyService, PasteInjector, EncryptionService,
                           SensitivityDetector, PurgeScheduler,
                           CaptureSettings, TextDetector, SnippetExpander,
                           ImageThumbnailer
  Services/Sync/         ← CloudSyncEngine, ClipRecordMapper, SyncQueue,
                           ConflictResolver
  Views/MenuBar/         ← PopoverRoot, HistoryList, ClipRow, SearchField
  Views/Main/            ← MainWindowRoot, Sidebar, HistoryBrowser,
                           HistoryDetail, SnippetsView, StatsView,
                           WindowRouter
  Views/Main/Settings/   ← SettingsView, GeneralPane, PrivacyPane,
                           HotkeysPane, DataPane, TagsPane
  Views/Onboarding/      ← OnboardingWindow + 4 step views
  DesignSystem/          ← Tokens, Theme, GlassCard, ClipPreview,
                           ThumbView, AppIconView, EmptyStateView
  Resources/             ← Assets.xcassets (AppIcon, AccentColor,
                           LogoMark, LogoGlyph, MenuBarTemplate),
                           Info.plist
LumeTests/               ← unit tests (29 currently)
LumeBenchmarks/          ← performance benchmarks
```
