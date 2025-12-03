#!/bin/bash

# install_to_applications.sh
# Builds and installs textcliper to /Applications for production testing

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_FILE="$PROJECT_DIR/textcliper.xcodeproj"
SCHEME="textcliper"
CONFIGURATION="Release"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  textcliper Installation to /Applications${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Step 1: Build Release configuration
echo -e "${YELLOW}[1/6]${NC} Building Release configuration..."
xcodebuild build \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    | grep -E "^(Build succeeded|Build failed|error:|warning:)" || true

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build succeeded${NC}"
echo ""

# Step 2: Find the built app
echo -e "${YELLOW}[2/6]${NC} Locating built app..."
DERIVED_DATA_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "textcliper-*" -type d -maxdepth 1 | while read dir; do echo "$(stat -f%m "$dir") $dir"; done | sort -rn | head -1 | cut -d' ' -f2-)

if [ -z "$DERIVED_DATA_PATH" ]; then
    echo -e "${RED}❌ Could not find DerivedData path${NC}"
    exit 1
fi

BUILT_APP="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/textcliper.app"

if [ ! -d "$BUILT_APP" ]; then
    echo -e "${RED}❌ Built app not found at: $BUILT_APP${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found app at: $BUILT_APP${NC}"
echo ""

# Step 3: Terminate running instances
echo -e "${YELLOW}[3/6]${NC} Checking for running instances..."
if pgrep -x "textcliper" > /dev/null; then
    echo "  Terminating running textcliper..."
    killall textcliper 2>/dev/null || true
    sleep 1
    echo -e "${GREEN}✓ Running instances terminated${NC}"
else
    echo -e "${GREEN}✓ No running instances found${NC}"
fi
echo ""

# Step 4: Remove old version from /Applications
echo -e "${YELLOW}[4/6]${NC} Removing old version from /Applications..."
if [ -d "/Applications/textcliper.app" ]; then
    rm -rf "/Applications/textcliper.app"
    echo -e "${GREEN}✓ Old version removed${NC}"
else
    echo -e "${GREEN}✓ No old version found${NC}"
fi
echo ""

# Step 5: Copy new version to /Applications
echo -e "${YELLOW}[5/6]${NC} Installing to /Applications..."
cp -R "$BUILT_APP" "/Applications/"

if [ ! -d "/Applications/textcliper.app" ]; then
    echo -e "${RED}❌ Installation failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Installed to /Applications/textcliper.app${NC}"
echo ""

# Step 6: Launch the app
echo -e "${YELLOW}[6/6]${NC} Launching textcliper..."
open "/Applications/textcliper.app"
sleep 2

if pgrep -x "textcliper" > /dev/null; then
    echo -e "${GREEN}✓ App launched successfully${NC}"
else
    echo -e "${YELLOW}⚠ App may not have launched (check System Settings for permissions)${NC}"
fi
echo ""

# Display next steps
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}✓ Installation Complete!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Grant Screen Recording permission:"
echo "   System Settings → Privacy & Security → Screen Recording"
echo "   → Enable 'textcliper' (NOT 'Xcode')"
echo ""
echo "2. Grant Accessibility permission (for ⌘⇧8 hotkey):"
echo "   System Settings → Privacy & Security → Accessibility"
echo "   → Enable 'textcliper'"
echo ""
echo "3. Test the app:"
echo "   • Click the menu bar icon"
echo "   • Try the ⌘⇧8 hotkey for interactive screenshot"
echo "   • Check OCR text extraction"
echo "   • Test clipboard copying"
echo ""
echo -e "${BLUE}The app is now installed as end users will experience it!${NC}"
echo ""
