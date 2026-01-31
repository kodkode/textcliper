#!/bin/bash

# Reset Onboarding Script for textclipper
# This script deletes the onboarding completion flag so you can see the onboarding flow again

echo "🔄 Resetting textclipper onboarding..."

# Delete the onboarding flag
defaults delete MIT.textclipper hasCompletedOnboarding 2>/dev/null

# Verify it was deleted
if defaults read MIT.textclipper hasCompletedOnboarding 2>/dev/null; then
    echo "❌ Failed to reset onboarding flag"
    exit 1
else
    echo "✅ Onboarding flag reset successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Build and run the app in Xcode (Cmd+R)"
    echo "2. The onboarding window will appear automatically"
fi
