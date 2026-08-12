#!/bin/bash
set -e

APP_NAME="TextClipper"
SCHEME="textclipper" # Adjusted to match user's target name from context
ARCHIVE_PATH="./build_temp/${APP_NAME}.xcarchive"
EXPORT_PATH="./build_temp/Export"
APP_SOURCE="${EXPORT_PATH}/${APP_NAME}.app"
DMG_NAME="TextClipper_Installer.dmg"

echo "🛠️  Building ${APP_NAME} from source..."

# Clean previous build
rm -rf "./build_temp"

# Build Archive
xcodebuild archive \
  -project "textclipper.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -archivePath "${ARCHIVE_PATH}" \
  -quiet || { echo "❌ Build failed"; exit 1; }

echo "📦 Exporting Archive with Developer ID signing..."

# Proper export with Developer ID signing (required for Sparkle updates)
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportOptionsPlist "./exportOptions.plist" \
  -exportPath "${EXPORT_PATH}" \
  -quiet || { echo "❌ Export failed"; exit 1; }

# The exported app name matches the scheme/target name
if [ -d "${EXPORT_PATH}/${SCHEME}.app" ] && [ ! -d "${APP_SOURCE}" ]; then
    mv "${EXPORT_PATH}/${SCHEME}.app" "${APP_SOURCE}"
fi

echo "✅ App exported and signed: ${APP_SOURCE}"

# Remove old DMG if it exists
if [ -f "$DMG_NAME" ]; then
    echo "🗑️  Removing old installer..."
    rm "$DMG_NAME"
fi

echo "💿 Creating DMG..."

if command -v create-dmg &> /dev/null; then
    create-dmg \
      --volname "${APP_NAME} Installer" \
      --window-pos 200 120 \
      --window-size 600 300 \
      --icon-size 100 \
      --icon "${APP_NAME}.app" 175 120 \
      --hide-extension "${APP_NAME}.app" \
      --app-drop-link 425 120 \
      "$DMG_NAME" \
      "$APP_SOURCE"
else
    # Fallback to hdiutil if create-dmg not installed
    echo "⚠️ create-dmg not found, using hdiutil fallback..."
    hdiutil create -volname "${APP_NAME}" -srcfolder "${APP_SOURCE}" -ov -format UDZO "${DMG_NAME}"
fi
echo ""
echo "✅ DMG Created Successfully: $DMG_NAME"
open .
