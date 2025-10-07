#!/bin/bash

# Build and sign script for textcliper
# This ensures stable code signing to prevent TCC permission loops

set -e

echo "🔨 Building textcliper..."
xcodebuild clean build -project textcliper.xcodeproj -scheme textcliper -configuration Debug 2>&1 | grep -E "BUILD|error|warning" | tail -10

echo ""
echo "✍️  Signing with Apple Development certificate..."
codesign --force --sign "Apple Development: michael.tubul@gmail.com (X4VTA8BYAW)" ~/Library/Developer/Xcode/DerivedData/textcliper*/Build/Products/Debug/textcliper.app

echo ""
echo "✅ Build and sign complete!"
echo ""
codesign -dvvv ~/Library/Developer/Xcode/DerivedData/textcliper*/Build/Products/Debug/textcliper.app 2>&1 | grep -E "Identifier|Authority|TeamIdentifier"
