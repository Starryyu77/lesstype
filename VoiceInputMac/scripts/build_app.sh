#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-debug}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="VoiceInputMac"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"

swift build -c "$CONFIGURATION"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Support/Info.plist" "$CONTENTS_DIR/Info.plist"
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

if [ -d "$BIN_DIR/${APP_NAME}_${APP_NAME}.bundle" ]; then
  cp -R "$BIN_DIR/${APP_NAME}_${APP_NAME}.bundle" "$RESOURCES_DIR/${APP_NAME}_${APP_NAME}.bundle"
fi

if command -v codesign >/dev/null 2>&1 && [ "${SKIP_CODESIGN:-0}" != "1" ]; then
  CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
  codesign --force --deep --sign "$CODESIGN_IDENTITY" --entitlements "$ROOT_DIR/Support/VoiceInputMac.entitlements" "$APP_DIR"
fi

echo "$APP_DIR"
