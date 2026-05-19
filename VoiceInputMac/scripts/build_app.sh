#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-debug}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="VoiceInputMac"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

resolve_codesign_identity() {
  if [ -n "${CODESIGN_IDENTITY+x}" ]; then
    printf '%s\n' "$CODESIGN_IDENTITY"
    return
  fi

  local identities
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"

  local identity
  identity="$(printf '%s\n' "$identities" | awk -F '"' '/"Apple Development:/{print $2; exit}')"
  if [ -n "$identity" ]; then
    printf '%s\n' "$identity"
    return
  fi

  identity="$(printf '%s\n' "$identities" | awk -F '"' '/"Developer ID Application:/{print $2; exit}')"
  if [ -n "$identity" ]; then
    printf '%s\n' "$identity"
    return
  fi

  printf '%s\n' "-"
}

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
  CODESIGN_IDENTITY="$(resolve_codesign_identity)"
  if [ "$CODESIGN_IDENTITY" = "-" ]; then
    echo "Signing with ad-hoc identity. For stable local permissions, create an Apple Development certificate in Xcode."
  else
    echo "Signing with identity: $CODESIGN_IDENTITY"
  fi
  codesign --force --deep --sign "$CODESIGN_IDENTITY" --entitlements "$ROOT_DIR/Support/VoiceInputMac.entitlements" "$APP_DIR"
fi

echo "$APP_DIR"
