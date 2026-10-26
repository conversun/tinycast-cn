#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
verify() {
  node Scripts/check-localization.js "$@"
  node --test Tests/localization-check-test.js
}
case "${1:-}" in
  "") verify ;;
  --extract)
    location=$(mktemp -d "${TMPDIR:-/tmp}/tinycast-localization.XXXXXX")
    trap 'rm -rf "$location"' EXIT
    xcodebuild -exportLocalizations -project Tinycast.xcodeproj \
      -localizationPath "$location" -exportLanguage zh-Hans SWIFT_EMIT_LOC_STRINGS=YES \
      > "$location/export.log" 2>&1 || { cat "$location/export.log"; exit 1; }
    found=false
    while IFS= read -r table; do
      found=true
      node Scripts/check-localization.js --extracted "$table"
    done < <(find "$location/zh-Hans.xcloc/Source Contents" -type f \
      \( -name Localizable.strings -o -name Localizable.xcstrings \))
    if [[ "$found" != true ]]; then
      echo 'No extracted Localizable table found in Xcode export.' >&2
      exit 1
    fi
    verify
    ;;
  --help)
    echo 'Usage: ./Scripts/check-localization.sh [--extract]'
    echo 'Default: shipped catalogs, all languages, dynamic titles and rendering checks. --extract: also build and compare Xcode extraction.'
    ;;
  *) echo 'Unknown option; use --help.' >&2; exit 2 ;;
esac
