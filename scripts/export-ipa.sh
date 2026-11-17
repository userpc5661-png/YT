#!/bin/bash
# Archive Layl and export an IPA. Run this on a Mac with Xcode signed in.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PLIST="${1:-ios/ExportOptions-development.plist}"
ARCHIVE="$ROOT/build/Layl.xcarchive"
EXPORT_DIR="$ROOT/build/ipa"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild was not found. Install Xcode on a Mac and run this script there." >&2
  exit 1
fi

if grep -q "YOUR_TEAM_ID" "$PLIST"; then
  echo "Edit $PLIST and replace YOUR_TEAM_ID with your 10-character Apple Team ID." >&2
  echo "Xcode shows it under Signing & Capabilities after you select a team." >&2
  exit 1
fi

echo "Archiving Layl (generic iOS device)..."
xcodebuild \
  -project "$ROOT/Layl.xcodeproj" \
  -scheme Layl \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  archive

echo "Exporting IPA with $PLIST ..."
rm -rf "$EXPORT_DIR"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$ROOT/$PLIST"

echo
echo "IPA exported to $EXPORT_DIR"
ls -lh "$EXPORT_DIR"/*.ipa
