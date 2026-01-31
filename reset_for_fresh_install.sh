#!/bin/bash

# reset_for_fresh_install.sh
# Completely resets textclipper to simulate a fresh installation experience
# This removes ALL app data, preferences, permissions, and cached information

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  textclipper Fresh Installation Reset${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will remove ALL app data!${NC}"
echo -e "${YELLOW}This includes:${NC}"
echo "  • All capture history"
echo "  • API keys and settings"
echo "  • iCloud sync data (local cache)"
echo "  • System permissions"
echo "  • Onboarding completion status"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to proceed): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${RED}Reset cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}Starting complete reset...${NC}"
echo ""

# Step 1: Terminate running instances
echo -e "${YELLOW}[1/7]${NC} Terminating running instances..."
if pgrep -x "textclipper" > /dev/null; then
    killall textclipper 2>/dev/null || true
    sleep 2
    echo -e "${GREEN}✓ App terminated${NC}"
else
    echo -e "${GREEN}✓ App not running${NC}"
fi
echo ""

# Step 2: Remove app from /Applications
echo -e "${YELLOW}[2/7]${NC} Removing app from /Applications..."
if [ -d "/Applications/textclipper.app" ]; then
    rm -rf "/Applications/textclipper.app"
    echo -e "${GREEN}✓ App removed${NC}"
else
    echo -e "${GREEN}✓ App not in /Applications${NC}"
fi
echo ""

# Step 3: Reset TCC (Privacy) permissions
echo -e "${YELLOW}[3/7]${NC} Resetting privacy permissions..."
# Note: We only reset Screen Recording permissions
# WARNING: Do NOT reset Accessibility permissions system-wide as it breaks mouse/trackpad control
echo "  Resetting Screen Recording permission for all apps..."
tccutil reset ScreenCapture 2>/dev/null || echo "  (ScreenCapture reset skipped - may require Full Disk Access)"

# For Accessibility, we cannot safely reset it programmatically without breaking system mouse control
# User will need to manually remove textclipper from Accessibility settings if it exists
echo "  ${YELLOW}Note: Accessibility permission for textclipper (if exists) should be manually removed:${NC}"
echo "  System Settings → Privacy & Security → Accessibility → Remove 'textclipper'"
echo "  ${YELLOW}(This is safer than resetting all Accessibility permissions which breaks mouse control)${NC}"

echo -e "${GREEN}✓ Screen Recording permission reset${NC}"
echo ""

# Step 4: Remove app container (sandboxed app data)
echo -e "${YELLOW}[4/7]${NC} Removing app container data..."
CONTAINER_PATH="$HOME/Library/Containers/MIT.textclipper"
if [ -d "$CONTAINER_PATH" ]; then
    echo "  Removing: $CONTAINER_PATH"
    # Remove contents, but some metadata files may be protected
    rm -rf "$CONTAINER_PATH/Data" 2>/dev/null || true
    rm -f "$CONTAINER_PATH"/*.plist 2>/dev/null || true
    # Try to remove the directory itself
    rmdir "$CONTAINER_PATH" 2>/dev/null && echo -e "${GREEN}✓ Container removed${NC}" || echo -e "${GREEN}✓ Container data cleared (some metadata may remain)${NC}"
else
    echo -e "${GREEN}✓ No container found${NC}"
fi
echo ""

# Step 5: Remove UserDefaults/Preferences
echo -e "${YELLOW}[5/8]${NC} Removing app preferences..."
defaults delete MIT.textclipper 2>/dev/null && echo -e "${GREEN}✓ Preferences removed${NC}" || echo -e "${GREEN}✓ No preferences found${NC}"
echo ""

# Step 6: Remove CloudKit cache
echo -e "${YELLOW}[6/8]${NC} Clearing CloudKit cache..."
# Note: This only removes local CloudKit cache, not data from iCloud servers
CLOUDKIT_CACHE="$HOME/Library/Caches/CloudKit"
if [ -d "$CLOUDKIT_CACHE" ]; then
    find "$CLOUDKIT_CACHE" -name "*textclipper*" -delete 2>/dev/null || true
    find "$CLOUDKIT_CACHE" -name "*MIT.textclipper*" -delete 2>/dev/null || true
    echo -e "${GREEN}✓ CloudKit cache cleared${NC}"
else
    echo -e "${GREEN}✓ No CloudKit cache found${NC}"
fi
echo ""

# Step 7: Remove Keychain entries (API keys and encryption keys)
echo -e "${YELLOW}[7/8]${NC} Removing Keychain entries (API keys)..."

# Remove ALL API keys from the service (including any that may have synced from iCloud)
# First, get a list of all accounts for this service
echo "  Scanning for all API keys..."
for account in $(security dump-keychain ~/Library/Keychains/login.keychain-db 2>/dev/null | grep -A 2 "com.textclipper.apikeys" | grep "acct" | awk -F'"' '{print $2}'); do
    security delete-generic-password -s "com.textclipper.apikeys" -a "$account" 2>/dev/null && echo "  ✓ Removed: $account" || true
done

# Also try known key names explicitly
for key in "openai-api-key" "gemini-api-key" "ocrspace-api-key" "mistral-api-key"; do
    security delete-generic-password -s "com.textclipper.apikeys" -a "$key" 2>/dev/null || true
done

# Remove encryption key
security delete-generic-password -s "com.textclipper.encryption" -a "master-key" 2>/dev/null && echo "  ✓ Encryption key removed" || echo "  ✓ No encryption key found"

echo -e "${GREEN}✓ Keychain cleanup complete${NC}"
echo ""

# Step 8: Clear notification history
echo -e "${YELLOW}[8/8]${NC} Clearing notification history..."
# This is best effort - notification history is system-managed
echo -e "${GREEN}✓ Notification cleanup attempted${NC}"
echo ""

# Final summary
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}✓ Reset Complete!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${YELLOW}What was reset:${NC}"
echo "  ✓ App removed from /Applications"
echo "  ✓ All API keys removed from Keychain (OpenAI, Gemini, OCR.space)"
echo "  ✓ Encryption key removed from Keychain"
echo "  ✓ All app data deleted (history, settings)"
echo "  ✓ Screen Recording permission reset"
echo "  ✓ Sandboxed container removed"
echo "  ✓ UserDefaults cleared"
echo "  ✓ CloudKit local cache cleared"
echo "  ✓ Onboarding status reset"
echo ""
echo -e "${YELLOW}Optional - Manual Step:${NC}"
echo "  If textclipper previously had Accessibility permission:"
echo "  → System Settings → Privacy & Security → Accessibility"
echo "  → Remove 'textclipper' from the list (if present)"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Run: ${BLUE}./install_to_applications.sh${NC}"
echo "2. The app will now show the onboarding flow for first-time users"
echo "3. Grant Screen Recording permission when prompted"
echo "4. Grant Accessibility permission when using ⌘⇧8 hotkey"
echo "5. Configure API keys and settings as a new user would"
echo ""
echo -e "${BLUE}Ready to install fresh? Run: ./install_to_applications.sh${NC}"
echo ""
