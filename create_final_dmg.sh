#!/bin/bash
set -e

# Source App Path (exported from Xcode Archive -> Distribute -> Developer ID -> Export)
APP_SOURCE="/Users/michaeltouboul/Desktop/TextClipper_Release/TextClipper.app"
DMG_NAME="TextClipper_Installer.dmg"

echo "📦 Preparing to package TextClipper from Golden Master..."

if [ ! -d "$APP_SOURCE" ]; then
    echo "❌ Error: Could not find the app at $APP_SOURCE"
    echo "👉 Make sure you have exported the notarized app to this folder."
    exit 1
fi

# Remove old DMG if it exists
if [ -f "$DMG_NAME" ]; then
    echo "🗑️  Removing old installer..."
    rm "$DMG_NAME"
fi

echo "💿 Creating DMG..."

create-dmg \
  --volname "TextClipper Installer" \
  --window-pos 200 120 \
  --window-size 600 300 \
  --icon-size 100 \
  --icon "TextClipper.app" 175 120 \
  --hide-extension "TextClipper.app" \
  --app-drop-link 425 120 \
  "$DMG_NAME" \
  "$APP_SOURCE"

echo ""
echo "✅ DMG Created Successfully: $DMG_NAME"
open .
