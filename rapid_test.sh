#!/bin/bash
set -e

echo "🚀 Rapid Build & Sign for Testing (Production Environment)..."

# 1. Archive (This creates a proper archive with provisioning profiles)
echo "📦 Archiving..."
xcodebuild archive \
    -project textclipper.xcodeproj \
    -scheme textclipper \
    -configuration Release \
    -archivePath ./build_temp/textclipper.xcarchive \
    | grep -E "error:|warning:|ARCHIVE SUCCEEDED"

# 2. Export (This signs it correctly using the exportOptions)
echo "📤 Exporting with Developer ID..."
xcodebuild -exportArchive \
    -archivePath ./build_temp/textclipper.xcarchive \
    -exportPath ./build_temp/Export \
    -exportOptionsPlist exportOptions.plist \
    | grep -E "error:|warning:|EXPORT SUCCEEDED"

APP_PATH="./build_temp/Export/textclipper.app"

echo "✅ App ready at: $APP_PATH"
echo "💥 Killing existing instances..."
killall textclipper 2>/dev/null || true

echo "🏃 Launching..."
open "$APP_PATH"
