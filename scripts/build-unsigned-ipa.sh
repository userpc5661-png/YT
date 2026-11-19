#!/bin/bash
# Build Layl for a generic iOS device with signing disabled, then zip
# Payload/Layl.app into build/ipa/Layl-unsigned.ipa.
# Intended for Codemagic and GitHub Actions macOS runners. Sideloadly signs it later.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DERIVED="$ROOT/build/DerivedData"
STAGE="$ROOT/build/ipa-stage"
OUT_DIR="$ROOT/build/ipa"
IPA="$OUT_DIR/Layl-unsigned.ipa"

echo "Xcode: $(xcodebuild -version | tr '\n' ' ')"
echo "Signing: CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO"

rm -rf "$DERIVED" "$STAGE" "$OUT_DIR"
mkdir -p "$OUT_DIR"

xcodebuild \
  -project "$ROOT/Layl.xcodeproj" \
  -scheme Layl \
  -configuration Release \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS=arm64 \
  build

APP="$(find "$DERIVED/Build/Products" -type d -path '*iphoneos/Layl.app' -print -quit)"
if [[ -z "${APP}" || ! -d "$APP" ]]; then
  echo "Layl.app was not produced for iphoneos." >&2
  find "$DERIVED/Build/Products" -maxdepth 3 -type d -name '*.app' >&2 || true
  exit 1
fi
echo "App bundle: $APP"

if [[ ! -f "$APP/Layl" ]]; then
  echo "Missing executable at $APP/Layl" >&2
  exit 1
fi

file "$APP/Layl"
if ! file "$APP/Layl" | grep -q "arm64"; then
  echo "Expected an arm64 device binary." >&2
  exit 1
fi

if command -v vtool >/dev/null 2>&1; then
  BUILD_INFO="$(vtool -show-build "$APP/Layl" || true)"
  echo "$BUILD_INFO"
  if echo "$BUILD_INFO" | grep -q "IOSSIMULATOR"; then
    echo "Refusing to package a simulator binary." >&2
    exit 1
  fi
fi

# The CI build is unsigned. Drop any signature leftovers so Sideloadly can sign cleanly.
rm -rf "$APP/_CodeSignature"
rm -f "$APP/embedded.mobileprovision"

mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/Layl.app"

(
  cd "$STAGE"
  zip -qry "$IPA" Payload
)

unzip -l "$IPA" | grep -q "Payload/Layl.app/Info.plist"
unzip -l "$IPA" | grep -q "Payload/Layl.app/Layl"

echo "Unsigned IPA: $IPA"
ls -lh "$IPA"
