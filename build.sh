#!/usr/bin/env bash
# build.sh - Build CmdTab and package as .app bundle
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="CmdTab"
SCRATCH="/tmp/CmdTab_build"
BUILD_DIR="$SCRATCH/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"

echo "Building ${APP_NAME} (release)..."
swift build -c release --scratch-path "$SCRATCH" 2>&1

BINARY="${BUILD_DIR}/${APP_NAME}"
if [ ! -f "$BINARY" ]; then
    echo "Build failed - binary not found at $BINARY"
    exit 1
fi

echo "Packaging ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${CONTENTS}/MacOS"
mkdir -p "${CONTENTS}/Resources"

cp "$BINARY" "${CONTENTS}/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${CONTENTS}/Info.plist"
if [ -f "Resources/${APP_NAME}.icns" ]; then
    cp "Resources/${APP_NAME}.icns" "${CONTENTS}/Resources/${APP_NAME}.icns"
fi
if [ -f "Resources/${APP_NAME}.png" ]; then
    cp "Resources/${APP_NAME}.png" "${CONTENTS}/Resources/${APP_NAME}.png"
fi

# Ensure binary is executable and remove any quarantine flags
chmod +x "${CONTENTS}/MacOS/${APP_NAME}"
xattr -cr "${APP_BUNDLE}" 2>/dev/null || true

# Sign with Hardened Runtime enabled.
# --options runtime  activates the Hardened Runtime, enforcing library validation,
#                    unsigned code injection prevention, and making the entitlements
#                    network-deny clauses binding at the kernel level.
# --entitlements     supplies the declared capability boundary for the process.
# --sign -           ad-hoc identity; replace with a Developer ID for notarization.
ENTITLEMENTS_FILE="${SCRIPT_DIR}/Resources/CmdTab.entitlements"
if [ -f "$ENTITLEMENTS_FILE" ]; then
    codesign --sign - --force --deep --options runtime \
        --entitlements "$ENTITLEMENTS_FILE" \
        "${APP_BUNDLE}" 2>/dev/null || true
else
    echo "Warning: entitlements file not found — signing without Hardened Runtime"
    codesign --sign - --force --deep "${APP_BUNDLE}" 2>/dev/null || true
fi

echo ""
echo "Done! -> ${SCRIPT_DIR}/${APP_BUNDLE}"
echo ""
echo "To launch:"
echo "  open \"${APP_BUNDLE}\""
echo ""
echo "First-run checklist:"
echo "  1. System Settings -> Privacy & Security -> Accessibility -> enable CmdTab"
echo "  2. System Settings -> Privacy & Security -> Screen Recording -> enable CmdTab"
echo "  3. Click the Dock icon or menu-bar icon to open the switcher"
echo "  4. Cmd+Tab or Option+Tab to switch application windows"
