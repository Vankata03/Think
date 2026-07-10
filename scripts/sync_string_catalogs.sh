#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
DERIVED_DATA="${LOCALIZATION_DERIVED_DATA:-$ROOT/.build/localization-derived-data}"
DESTINATION="${LOCALIZATION_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"

cd "$ROOT"
ruby scripts/generate_content_catalog.rb
xcodebuild build \
  -project Think.xcodeproj \
  -scheme Think \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  -quiet

BASE="$DERIVED_DATA/Build/Intermediates.noindex/Think.build"

sync_catalog() {
  local catalog="$1"
  local objects="$2"
  local args=()
  local stringsdata

  for stringsdata in "$objects"/*.stringsdata(N); do
    args+=(--stringsdata "$stringsdata")
  done
  if (( ${#args} == 0 )); then
    print -u2 "No stringsdata found for $catalog in $objects"
    return 1
  fi
  xcrun xcstringstool sync "$catalog" "${args[@]}"
}

sync_catalog_file_if_present() {
  local catalog="$1"
  local stringsdata="$2"
  if [[ ! -f "$stringsdata" ]]; then
    print "No InfoPlist stringsdata found at $stringsdata; keeping the manual catalog entries."
    return 0
  fi
  xcrun xcstringstool sync "$catalog" --stringsdata "$stringsdata"
}

sync_catalog Think/Localizable.xcstrings "$BASE/Debug-iphonesimulator/Think.build/Objects-normal/arm64"
sync_catalog ThinkWatch/Localizable.xcstrings "$BASE/Debug-watchsimulator/ThinkWatchApp.build/Objects-normal/arm64"
sync_catalog ThinkWidgets/Localizable.xcstrings "$BASE/Debug-iphonesimulator/ThinkWidgetsExtension.build/Objects-normal/arm64"
sync_catalog ThinkWatchWidgets/Localizable.xcstrings "$BASE/Debug-watchsimulator/ThinkWatchWidgetsExtension.build/Objects-normal/arm64"
sync_catalog_file_if_present Think/InfoPlist.xcstrings "${LOCALIZATION_INFOPLIST_STRINGSDATA:-$BASE/Debug-iphonesimulator/Think.build/InfoPlist.stringsdata}"

print "String catalogs synchronized."
