# Contributing to Lume

Thanks for your interest. Lume is small, focused, and opinionated — please
read this before opening a PR.

## Setup

```sh
brew install xcodegen
xcodegen generate -s Lume/project.yml
open Lume/Lume.xcodeproj
```

You need **Xcode 26** and **macOS 26 Tahoe** to build. We do not
support older OS versions; Liquid Glass requires the macOS 26 SDK.

## Principles

1. **Do less, better.** New features must earn their seat. If a
   feature can be a Smart Rule (regex → action) instead of native
   code, it should be.
2. **Fast paths must stay fast.** If your change touches the popover
   refresh, dedup write, or FTS query, run `LumeBenchmarks` and post
   the numbers in the PR.
3. **Liquid Glass first.** Don't reach for `.background(.regularMaterial)`
   if `.glassEffect()` does the job. Don't fight the system on light/dark.
4. **No telemetry. Ever.** Lume sends nothing anywhere except the user's
   own iCloud container.
5. **Plain Swift, no clever frameworks.** GRDB is our only runtime
   dependency and we'd like to keep it that way.

## Pull requests

- Branch from `main`.
- One concern per PR. Refactor PRs separately from feature PRs.
- Run the test suite (`xcodebuild test -scheme Lume`).
- Run benchmarks if you touched a hot path (`xcodebuild test -scheme LumeBenchmarks`).
- Update `CHANGELOG.md` under `[Unreleased]`.

## Reporting bugs

Open an issue. Include:

- macOS version (must be 26.x).
- Lume version.
- A reproduction.
- A `~/Library/Logs/Lume/lume.log` excerpt if relevant.

## Style

- Swift 6, strict concurrency on.
- Two-space indent.
- No comments restating the code; only comments that explain *why*
  something non-obvious is the way it is.
- Names: `Service` for actors with side effects, `Repository` for DB
  access, `Engine` for state machines, `Controller` for AppKit shells.
