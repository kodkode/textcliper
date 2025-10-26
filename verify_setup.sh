#!/bin/bash

echo "🔍 Verifying textcliper App Store setup..."
echo ""

# Check if entitlements file exists
if [ -f "textcliper/textcliper.entitlements" ]; then
    echo "✅ Entitlements file exists"
else
    echo "❌ Entitlements file NOT found"
fi

# Check if iCloudSyncService exists
if [ -f "textcliper/iCloudSyncService.swift" ]; then
    echo "✅ iCloudSyncService.swift exists"
else
    echo "❌ iCloudSyncService.swift NOT found"
fi

# Check if App Sandbox is in entitlements
if grep -q "com.apple.security.app-sandbox" textcliper/textcliper.entitlements; then
    echo "✅ App Sandbox enabled in entitlements"
else
    echo "❌ App Sandbox NOT enabled in entitlements"
fi

# Check if iCloud entitlements are present
if grep -q "com.apple.developer.icloud-container-identifiers" textcliper/textcliper.entitlements; then
    echo "✅ iCloud entitlements present"
else
    echo "❌ iCloud entitlements NOT present"
fi

# Check if entitlements are linked in project
if grep -q "CODE_SIGN_ENTITLEMENTS" textcliper.xcodeproj/project.pbxproj; then
    echo "✅ Entitlements linked in project"
else
    echo "⚠️  Entitlements NOT linked in project - YOU NEED TO DO THIS IN XCODE!"
    echo "   Go to Build Settings → Search 'Code Signing Entitlements' → Set to 'textcliper/textcliper.entitlements'"
fi

# Check bundle ID
BUNDLE_ID=$(xcodebuild -showBuildSettings -project textcliper.xcodeproj -scheme textcliper 2>/dev/null | grep "PRODUCT_BUNDLE_IDENTIFIER = " | head -1 | sed 's/.*= //')
if [ ! -z "$BUNDLE_ID" ]; then
    echo "✅ Bundle ID: $BUNDLE_ID"
else
    echo "⚠️  Could not determine Bundle ID"
fi

# Check team
TEAM=$(xcodebuild -showBuildSettings -project textcliper.xcodeproj -scheme textcliper 2>/dev/null | grep "DEVELOPMENT_TEAM = " | head -1 | sed 's/.*= //')
if [ ! -z "$TEAM" ]; then
    echo "✅ Development Team: $TEAM"
else
    echo "⚠️  No development team set"
fi

echo ""
echo "🎯 Next Steps:"
echo "1. Open Xcode: open textcliper.xcodeproj"
echo "2. Go to Build Settings → Search 'Code Signing Entitlements'"
echo "3. Set value to: textcliper/textcliper.entitlements"
echo "4. Add iCloudSyncService.swift to project (Right-click folder → Add Files)"
echo "5. Build and run!"
