#!/usr/bin/env bash
# build-app.sh — Build Meridian.app (Bankrate edition)
# Produces a self-contained .app in ./build/ ready to distribute or drag to /Applications.
#
# Usage:
#   ./build-app.sh           # debug build (fast)
#   ./build-app.sh release   # release build (optimised, smaller)

set -euo pipefail

CONFIG="${1:-debug}"
PRODUCT="Meridian"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$PRODUCT.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

# Sparkle auto-update — appcast hosted on the public meridian GitHub Pages site.
SPARKLE_FEED_URL="https://rbcodelabs.github.io/meridian/bankrate/appcast.xml"
SPARKLE_PUBLIC_KEY="NUlUXdomYQaFCld5icDl1FxgdQ4Uw/Bp7VQnYHqqL0I="

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
    <string>com.bankrate.meridian</string>
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
    <string>© 2026 Bankrate</string>
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

if [[ "${OPEN:-0}" == "1" ]]; then
    open "$APP_DIR"
fi
