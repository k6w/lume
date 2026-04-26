#!/usr/bin/env bash
# Run the LumeBenchmarks scheme under xcodebuild's Release config and
# print a digest. CI uses this to fail any PR that regresses a budget
# by more than 10%.
#
# Usage: ./scripts/perf-trace.sh
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="Lume/Lume.xcodeproj"
[[ -d "$PROJECT" ]] || xcodegen generate -s Lume/project.yml

xcodebuild \
  -project "$PROJECT" \
  -scheme LumeBenchmarks \
  -configuration Release \
  -resultBundlePath build/perf.xcresult \
  test 2>&1 | tee build/perf.log

echo "Run \"xcrun xcresulttool get --path build/perf.xcresult --format json\" for the full breakdown."
