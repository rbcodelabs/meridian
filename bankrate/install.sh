#!/bin/bash
set -e

echo "📥 Downloading Bankrate Meridian..."
TMPDIR=$(mktemp -d)
curl -fsSL "https://rbcodelabs.github.io/meridian/bankrate/Bankrate-Meridian-1.0.0.zip" \
  -o "$TMPDIR/Bankrate-Meridian.zip"

echo "📦 Installing..."
unzip -q "$TMPDIR/Bankrate-Meridian.zip" -d "$TMPDIR"
xattr -cr "$TMPDIR/Meridian.app"

# Install to /Applications (use sudo if needed)
if [ -w "/Applications" ]; then
  [ -d "/Applications/Meridian.app" ] && rm -rf "/Applications/Meridian.app"
  mv "$TMPDIR/Meridian.app" "/Applications/Meridian.app"
else
  [ -d "/Applications/Meridian.app" ] && sudo rm -rf "/Applications/Meridian.app"
  sudo mv "$TMPDIR/Meridian.app" "/Applications/Meridian.app"
fi
rm -rf "$TMPDIR"

echo "🚀 Launching..."
open /Applications/Meridian.app
