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

# A failed listing (say, a missing base ref) must fail the lint, not pass it
# as an empty file list.
if ! listing="$("${list[@]}")"; then
    echo "lint.sh: could not list Swift files (${list[*]})" >&2
    exit 2
fi

files=()
while IFS= read -r f; do
    [ -z "$f" ] && continue
    # Staged files are read from the index, so they need not exist on disk.
    if [ "$mode" = "--staged" ] || [ -f "$f" ]; then files+=("$f"); fi
done <<<"$listing"

if [ ${#files[@]} -eq 0 ]; then
    echo "lint.sh: no Swift files to lint"
    exit 0
fi

echo "lint.sh: swift-format lint on ${#files[@]} file(s)"
report="$(mktemp -t think-lint)"
status=0
if [ "$mode" = "--staged" ]; then
    # Lint the staged snapshot, not the working tree, so unstaged edits
    # neither fail nor rescue the commit.
    for f in "${files[@]}"; do
        git show ":$f" \
            | xcrun swift-format lint --strict --configuration .swift-format --assume-filename "$f" - \
                >>"$report" 2>&1 \
            || status=1
    done
else
    xcrun swift-format lint --strict --parallel "${files[@]}" >"$report" 2>&1 || status=1
fi
if [ "$status" -eq 0 ]; then
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
