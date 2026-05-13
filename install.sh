#!/bin/bash
set -e

echo "📥 Downloading Obsidian Setup..."
TMPDIR=$(mktemp -d)
curl -fsSL "https://github.com/rbcodelabs/ObsidianSetup/releases/latest/download/ObsidianSetup.zip" \
  -o "$TMPDIR/ObsidianSetup.zip"

echo "📦 Installing..."
unzip -q "$TMPDIR/ObsidianSetup.zip" -d "$TMPDIR"
xattr -cr "$TMPDIR/ObsidianSetup.app"

# Remove old version if present
[ -d "/Applications/ObsidianSetup.app" ] && rm -rf "/Applications/ObsidianSetup.app"
mv "$TMPDIR/ObsidianSetup.app" "/Applications/ObsidianSetup.app"
rm -rf "$TMPDIR"

echo "🚀 Launching..."
open /Applications/ObsidianSetup.app
