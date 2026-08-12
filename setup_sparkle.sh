#!/bin/bash

# Configuration
SPARKLE_VERSION="2.6.4"
DOWNLOAD_URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
TOOLS_DIR="./sparkle_tools"

echo "✨ Setting up Sparkle Updater Tools..."

# Create tools directory
mkdir -p "$TOOLS_DIR"

# Download Sparkle if not present
if [ ! -f "$TOOLS_DIR/bin/generate_keys" ]; then
    echo "⬇️  Downloading Sparkle ${SPARKLE_VERSION}..."
    curl -L -o "Sparkle.tar.xz" "$DOWNLOAD_URL"
    
    echo "📦 Extracting tools..."
    tar -xf "Sparkle.tar.xz" -C "$TOOLS_DIR"
    rm "Sparkle.tar.xz"
    
    echo "✅ Sparkle tools installed in $TOOLS_DIR"
else
    echo "✅ Sparkle tools already present."
fi

# Check for keys
if [ ! -f "dsa_priv.pem" ]; then
    echo "🔑 Generating EdDSA keys for signing updates..."
    "$TOOLS_DIR/bin/generate_keys"
    
    echo ""
    echo "⚠️  IMPORTANT: Backup 'dsa_priv.pem' securely! Do not share it."
    echo "   The public key has been printed above. You need to add it to Info.plist"
    echo "   key: SUPublicEDKey"
    echo "   value: <your_public_key>"
else
    echo "✅ Signing keys already exist."
fi

echo ""
echo "🚀 NEXT STEPS:"
echo "1. Open Xcode and add package dependency: https://github.com/sparkle-project/Sparkle"
echo "2. Add 'SUPublicEDKey' to Info.plist with the key generated above."
echo "3. Add 'SUFeedURL' to Info.plist (e.g., https://your-firebase-site.web.app/appcast.xml)"
echo "4. Build your app using 'generate_appcast.sh' when ready to release."
