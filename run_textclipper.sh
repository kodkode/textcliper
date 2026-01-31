#!/bin/bash

# Build and run textclipper with stable permissions
# This script prevents permission resets during development

APP_NAME="textclipper"
BUILD_DIR="$HOME/Library/Developer/Xcode/DerivedData/${APP_NAME}-*/Build/Products/Debug"

echo "🔨 Building $APP_NAME..."
xcodebuild build -project ${APP_NAME}.xcodeproj -scheme ${APP_NAME} -configuration Debug

echo "🚀 Launching $APP_NAME..."
open $(find ~/Library/Developer/Xcode/DerivedData -name "${APP_NAME}.app" -path "*/Debug/*" | head -1)

echo "✅ Done! Grant accessibility permission to ${APP_NAME}.app (not Xcode) in System Settings."
