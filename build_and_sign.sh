#!/bin/bash

# Build and sign script for textclipper
# This ensures stable code signing to prevent TCC permission loops

set -e

echo "🔨 Building textclipper..."
xcodebuild clean build -project textclipper.xcodeproj -scheme textclipper -configuration Debug 2>&1 | grep -E "BUILD|error|warning" | tail -10

echo ""
echo "✍️  Signing with Apple Development certificate..."
codesign --force --sign "Apple Development: michael.tubul@gmail.com (X4VTA8BYAW)" ~/Library/Developer/Xcode/DerivedData/textclipper*/Build/Products/Debug/textclipper.app

echo ""
echo "✅ Build and sign complete!"
echo ""
codesign -dvvv ~/Library/Developer/Xcode/DerivedData/textclipper*/Build/Products/Debug/textclipper.app 2>&1 | grep -E "Identifier|Authority|TeamIdentifier"
