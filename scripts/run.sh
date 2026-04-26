#!/usr/bin/env bash
# One-shot: regenerate project, build Debug, launch Lume.app.
# Re-run any time you change Swift sources.
#
# Usage:
#   ./scripts/run.sh           # build + launch
#   ./scripts/run.sh kill      # quit any running Lume
#   ./scripts/run.sh test      # run the unit tests
#   ./scripts/run.sh bench     # run the perf benchmarks
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT_DIR="Lume"
PROJECT="$PROJECT_DIR/Lume.xcodeproj"
SCHEME="Lume"
DD="$PROJECT_DIR/build/dd"

ensure_xcodegen() {
  command -v xcodegen >/dev/null 2>&1 || {
    echo "Installing xcodegen…"
    brew install xcodegen
  }
}

regen() {
  ensure_xcodegen
  (cd "$PROJECT_DIR" && xcodegen generate -s project.yml)
}

build() {
  [[ -d "$PROJECT" ]] || regen
  echo "Building Lume (Debug)…"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -derivedDataPath "$DD" \
    build \
    -quiet
}

kill_running() {
  pkill -x Lume 2>/dev/null || true
}

launch() {
  local app="$DD/Build/Products/Debug/Lume.app"
  if [[ ! -d "$app" ]]; then
    echo "no Lume.app at $app — did the build fail?" >&2
    exit 1
  fi
  echo "Launching $app"
  open "$app"
  echo
  echo "  ▸ Look for the Lume glyph in your menu bar (top-right)."
  echo "  ▸ Click once → wait for the popover to open."
  echo "  ▸ Click twice quickly → opens the full app window."
  echo "  ▸ Copy something — it should appear in the popover instantly."
  echo
  echo "  Logs:    log stream --process Lume --level debug"
  echo "  Storage: ~/Library/Containers/app.lume.Lume/Data/Library/Application Support/Lume/lume.sqlite"
  echo "  Stop:    ./scripts/run.sh kill"
}

run_tests() {
  [[ -d "$PROJECT" ]] || regen
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -derivedDataPath "$DD" \
    test
}

run_bench() {
  [[ -d "$PROJECT" ]] || regen
  xcodebuild \
    -project "$PROJECT" \
    -scheme LumeBenchmarks \
    -configuration Release \
    -derivedDataPath "$DD" \
    test
}

cmd="${1:-launch}"
case "$cmd" in
  launch|"")  kill_running; build; launch ;;
  build)      build ;;
  regen)      regen ;;
  kill)       kill_running; echo "stopped." ;;
  test)       run_tests ;;
  bench)      run_bench ;;
  *)          echo "usage: $0 [launch|build|regen|kill|test|bench]" >&2; exit 1 ;;
esac
