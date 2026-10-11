#!/bin/bash
# Lint Swift files with swift-format (rules in .swift-format). Only changed
# files are checked: the codebase predates the config, so this ratchets style
# forward one touched file at a time.
#
# Usage: ci_scripts/lint.sh [<base-ref>]  files differing from base, including
#                                         uncommitted edits (default: origin/develop)
#        ci_scripts/lint.sh --staged      files staged for commit (pre-commit hook)
#        ci_scripts/lint.sh --all         every Swift file
#
# Fix a flagged file in place: xcrun swift-format format -i <file>

set -euo pipefail
cd "$(dirname "$0")/.."

mode="${1:-origin/develop}"
case "$mode" in
    --staged) list=(git diff --cached --name-only --diff-filter=ACMR -- '*.swift') ;;
    --all) list=(git ls-files -- '*.swift') ;;
    *) list=(git diff --name-only --diff-filter=ACMR "$mode" -- '*.swift') ;;
esac

files=()
while IFS= read -r f; do
    [ -f "$f" ] && files+=("$f")
done < <("${list[@]}")

if [ ${#files[@]} -eq 0 ]; then
    echo "lint.sh: no Swift files to lint"
    exit 0
fi

echo "lint.sh: swift-format lint on ${#files[@]} file(s)"
report="$(mktemp -t think-lint)"
if xcrun swift-format lint --strict --parallel "${files[@]}" >"$report" 2>&1; then
    rm -f "$report"
    exit 0
fi

# Condensed report: findings per file, then the first few in full.
echo "Findings per file:"
grep -E '^[^:]+\.swift:[0-9]+' "$report" | cut -d: -f1 | sort | uniq -c | sort -rn
echo "First findings:"
head -n 20 "$report"
echo "Full report: $report" >&2
echo "Fix with: xcrun swift-format format -i <file>" >&2
exit 1
