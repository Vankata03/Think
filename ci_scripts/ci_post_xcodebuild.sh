#!/bin/zsh

set -eu

# Deploy workflow variables:
# ASC_CREATE_APP_STORE_VERSION=YES, plus secret ASC_KEY_ID,
# ASC_ISSUER_ID, and ASC_PRIVATE_KEY_BASE64.
# Opt in only from the release archive workflow. Other Xcode Cloud actions and
# local builds must remain unaffected.
if [[ "${CI_XCODE_CLOUD:-}" != "TRUE" || "${CI_XCODEBUILD_ACTION:-}" != "archive" ]]; then
    exit 0
fi

if [[ "${CI_XCODEBUILD_EXIT_CODE:-1}" != "0" ]]; then
    echo "Skipping App Store version creation because archive failed."
    exit 0
fi

if [[ "${ASC_CREATE_APP_STORE_VERSION:-}" != "YES" ]]; then
    echo "Skipping App Store version creation; ASC_CREATE_APP_STORE_VERSION is not YES."
    exit 0
fi

if [[ "${CI_PRODUCT_PLATFORM:-}" != "iOS" ]]; then
    echo "Skipping App Store version creation for ${CI_PRODUCT_PLATFORM:-unknown} archive."
    exit 0
fi

archive_info="${CI_ARCHIVE_PATH:?CI_ARCHIVE_PATH is required}/Info.plist"
if [[ ! -f "$archive_info" ]]; then
    echo "error: Archive Info.plist not found at $archive_info" >&2
    exit 1
fi

version=$(/usr/libexec/PlistBuddy \
    -c "Print :ApplicationProperties:CFBundleShortVersionString" \
    "$archive_info")
bundle_id=$(/usr/libexec/PlistBuddy \
    -c "Print :ApplicationProperties:CFBundleIdentifier" \
    "$archive_info")

script_directory="${0:A:h}"
arguments=(
    ensure-version
    --version "$version"
    --bundle-id "$bundle_id"
    --platform IOS
)
if [[ -n "${ASC_APP_ID:-}" ]]; then
    arguments+=(--app-id "$ASC_APP_ID")
fi

echo "Ensuring App Store version $version exists before Xcode Cloud distribution."
/usr/bin/python3 "$script_directory/app_store_connect.py" "${arguments[@]}"
