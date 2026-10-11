#!/bin/bash
# Build and test Think the same way CI does. CI calls this script, so a local
# green run means the same commands pass on the runner.
#
# Usage: ci_scripts/test.sh [--build-only] [--skip-ui] [--only <Target[/Class[/method]]>]...
#
# Environment:
#   THINK_TEST_DEVICE  simulator name (default: iPhone 17 Pro)
#   DERIVED_DATA       derived data path (default: DerivedData)
#   LOG_DIR            full xcodebuild logs (default: DerivedData/BuildLogs)
#   RESULT_BUNDLE      .xcresult path; replaced if it exists (default: none)
#   XCBEAUTIFY_ARGS    extra xcbeautify arguments, e.g. "--renderer github-actions"
#
# Output is condensed (xcbeautify when installed, otherwise xcodebuild -quiet).
# On failure, grep the full log in LOG_DIR for "error:" or "failed".

set -euo pipefail
cd "$(dirname "$0")/.."

device="${THINK_TEST_DEVICE:-iPhone 17 Pro}"
derived_data="${DERIVED_DATA:-DerivedData}"
log_dir="${LOG_DIR:-$derived_data/BuildLogs}"
result_bundle="${RESULT_BUNDLE:-}"
build_only=false
test_args=()

while (($#)); do
    case "$1" in
        --build-only) build_only=true ;;
        --skip-ui) test_args+=(-skip-testing:ThinkUITests) ;;
        --only) shift; test_args+=("-only-testing:$1") ;;
        *) echo "test.sh: unknown option '$1'" >&2; exit 2 ;;
    esac
    shift
done

common=(
    -project Think.xcodeproj
    -scheme Think
    -testPlan Think
    -destination "platform=iOS Simulator,name=$device,OS=latest"
    -derivedDataPath "$derived_data"
    CODE_SIGNING_ALLOWED=NO
)

if command -v xcbeautify >/dev/null; then
    quiet=()
    # shellcheck disable=SC2086
    condense() { xcbeautify ${XCBEAUTIFY_ARGS:-}; }
else
    quiet=(-quiet)
    condense() { cat; }
fi

mkdir -p "$log_dir"

run() {
    local name="$1"
    shift
    echo "==> xcodebuild $name (log: $log_dir/$name.log)"
    if ! NSUnbufferedIO=YES xcodebuild "$name" ${quiet[@]+"${quiet[@]}"} "$@" 2>&1 \
        | tee "$log_dir/$name.log" | condense; then
        echo "xcodebuild $name failed; full log: $log_dir/$name.log" >&2
        exit 1
    fi
}

run build-for-testing "${common[@]}"
$build_only && exit 0

if [ -n "$result_bundle" ]; then
    rm -rf "$result_bundle"
    mkdir -p "$(dirname "$result_bundle")"
    test_args+=(-resultBundlePath "$result_bundle")
fi

run test-without-building "${common[@]}" ${test_args[@]+"${test_args[@]}"}
