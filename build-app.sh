#!/usr/bin/env bash
# build-app.sh — Build Meridian.app bundle
# Produces a self-contained .app in ./build/ ready to distribute or drag to /Applications.
#
# Usage:
#   ./build-app.sh           # debug build (fast)
#   ./build-app.sh release   # release build (optimised, smaller)

set -euo pipefail

CONFIG="${1:-debug}"
PRODUCT="Meridian"

# Sparkle auto-update settings.
# SPARKLE_FEED_URL can be overridden at build time for org forks:
#   SPARKLE_FEED_URL=https://... ./build-app.sh release
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://rbcodelabs.github.io/meridian/appcast.xml}"
SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-XRZZFzGQX/r/gOPcn+l+E+1I5LHXX+ZF0CkdR2cnmYs=}"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$PRODUCT.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "▶ Building ($CONFIG)..."
if [[ "$CONFIG" == "release" ]]; then
    swift build -c release 2>&1 | tail -3
    BINARY=".build/release/$PRODUCT"
else
    swift build 2>&1 | tail -3
    BINARY=".build/debug/$PRODUCT"
fi

echo "▶ Assembling $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

# Binary
cp "$BINARY" "$MACOS/$PRODUCT"

# Icon
ICNS_SRC="Sources/$PRODUCT/Resources/AppIcon.icns"
if [[ -f "$ICNS_SRC" ]]; then
    cp "$ICNS_SRC" "$RESOURCES/AppIcon.icns"
fi

# Info.plist
cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$PRODUCT</string>
    <key>CFBundleIdentifier</key>
    <string>com.rbcodelabs.meridian</string>
    <key>CFBundleName</key>
    <string>Meridian</string>
    <key>CFBundleDisplayName</key>
    <string>Meridian</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026 rbcodelabs</string>
    <key>SUFeedURL</key>
    <string>$SPARKLE_FEED_URL</string>
    <key>SUPublicEDKey</key>
    <string>$SPARKLE_PUBLIC_KEY</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
</dict>
</plist>
EOF

echo "  ✓ $APP_DIR"
echo ""
echo "  Open with:  open $APP_DIR"
echo "  Install:    cp -r $APP_DIR /Applications/"
echo ""

# Optionally open it immediately
if [[ "${OPEN:-0}" == "1" ]]; then
    open "$APP_DIR"
fi
