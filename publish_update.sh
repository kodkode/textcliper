#!/bin/bash

# Configuration
APP_NAME="textclipper"
DMG_NAME="TextClipper_Installer.dmg" # Matches website link
APPCAST_FILE="appcast.xml"
PRIVATE_KEY_PATH="dsa_priv.pem" 
GenerateAppcastTool="./sparkle_tools/bin/generate_appcast"
SignUpdateTool="./sparkle_tools/bin/sign_update"
WEBSITE_URL="https://textclipper.app"
DOWNLOADS_PATH="downloads"

echo "🚀 Building and packaging ${APP_NAME} for distribution..."

# 1. Build and Archive
./create_final_dmg.sh
# Ensure this script creates ./TextClipper_Installer.dmg

if [ ! -f "TextClipper_Installer.dmg" ]; then
    echo "❌ Failed to create DMG."
    exit 1
fi

# 2. Check for Sparkle tools
if [ ! -f "$GenerateAppcastTool" ]; then
    echo "⚠️ Sparkle tools not found. Running setup..."
    ./setup_sparkle.sh
fi

echo "📂 Moving DMG to ${DOWNLOADS_PATH}..."
mkdir -p "${DOWNLOADS_PATH}"
mv "${DMG_NAME}" "${DOWNLOADS_PATH}/"

# 3. Generate Appcast using official tool (Available in PATH or relative)
echo "📝 Generating appcast.xml with official tool..."

# The tool will scan the directory and generate appcast for all archives
"$GenerateAppcastTool" "${DOWNLOADS_PATH}"

echo "✅ Appcast generated at ${DOWNLOADS_PATH}/${APPCAST_FILE}"

echo ""
echo "☁️  UPLOAD INSTRUCTIONS:"
echo "1. Run 'firebase deploy' (files are already in place)."
