#!/bin/bash

echo "=== Permission Check ==="
echo ""

# Check Screen Recording permission
echo "Screen Recording Permission:"
if /usr/sbin/screencapture -x /tmp/test_screenshot.png 2>&1 | grep -q "not allowed"; then
    echo "  ❌ NOT GRANTED"
else
    echo "  ✅ Granted or First Run"
    rm -f /tmp/test_screenshot.png
fi

echo ""
echo "To check manually:"
echo "  System Settings > Privacy & Security > Screen Recording"
echo "  Look for: 'Xcode' or 'textcliper'"
