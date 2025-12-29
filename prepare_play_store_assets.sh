#!/bin/bash

# Play Store Assets Preparation Script
# Run this script to prepare all necessary assets for Play Store submission

set -e

echo "🎨 True Home - Play Store Assets Preparation"
echo "============================================"

# Create directories
ASSETS_DIR="$HOME/truehome_playstore_assets"
SCREENSHOTS_DIR="$ASSETS_DIR/screenshots"
GRAPHICS_DIR="$ASSETS_DIR/graphics"

mkdir -p "$SCREENSHOTS_DIR"
mkdir -p "$GRAPHICS_DIR"

echo ""
echo "📁 Created directories:"
echo "   - $SCREENSHOTS_DIR"
echo "   - $GRAPHICS_DIR"

# Check if device is connected
echo ""
echo "📱 Checking for connected device..."
DEVICE=$(adb devices | grep -w "device" | head -1 | awk '{print $1}')

if [ -z "$DEVICE" ]; then
    echo "❌ No device connected. Please connect your Android device and enable USB debugging."
    exit 1
fi

echo "✅ Device connected: $DEVICE"

# Function to capture screenshot
capture_screenshot() {
    local name=$1
    local filename="screenshot_$name.png"
    
    echo ""
    echo "📸 Ready to capture: $name"
    echo "   Press ENTER when the screen is ready..."
    read
    
    adb shell screencap -p /sdcard/$filename
    adb pull /sdcard/$filename "$SCREENSHOTS_DIR/$filename"
    adb shell rm /sdcard/$filename
    
    echo "   ✅ Saved: $SCREENSHOTS_DIR/$filename"
}

echo ""
echo "📸 Screenshot Capture Guide"
echo "============================"
echo ""
echo "You need at least 2 screenshots (recommended 4-8):"
echo "1. Home screen with property listings"
echo "2. Property detail page"
echo "3. Search/filter screen (optional)"
echo "4. Profile/favorites screen (optional)"
echo "5. Map view (optional)"
echo ""
echo "Tips:"
echo "- Hold your phone in portrait mode"
echo "- Make sure the screen shows real data (not empty states)"
echo "- Avoid showing personal information"
echo ""
read -p "Do you want to capture screenshots now? (y/n): " CAPTURE_SCREENSHOTS

if [ "$CAPTURE_SCREENSHOTS" = "y" ] || [ "$CAPTURE_SCREENSHOTS" = "Y" ]; then
    capture_screenshot "1_home_screen"
    capture_screenshot "2_property_detail"
    
    read -p "Capture more screenshots? (y/n): " MORE
    if [ "$MORE" = "y" ] || [ "$MORE" = "Y" ]; then
        capture_screenshot "3_search_filter"
        capture_screenshot "4_profile_favorites"
    fi
    
    echo ""
    echo "✅ Screenshots captured!"
fi

# Copy app icon
echo ""
echo "🎯 Copying app icon..."
ICON_PATH="android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
if [ -f "$ICON_PATH" ]; then
    cp "$ICON_PATH" "$GRAPHICS_DIR/app_icon_512x512.png"
    echo "✅ App icon copied (you may need to resize to 512x512)"
else
    echo "⚠️  App icon not found at $ICON_PATH"
fi

# Create feature graphic template info
echo ""
echo "🖼️  Feature Graphic"
echo "=================="
echo "You need to create a 1024x500 feature graphic."
echo "This appears at the top of your Play Store listing."
echo ""
echo "Suggestions:"
echo "- Use your app logo/branding"
echo "- Add tagline: 'Find Your Perfect Home in Uganda'"
echo "- Use your app's color scheme"
echo ""
echo "Tools you can use:"
echo "- Canva (free, easy): https://canva.com"
echo "- GIMP (free, powerful): https://gimp.org"
echo "- Photoshop/Figma (professional)"
echo ""
echo "Save as: $GRAPHICS_DIR/feature_graphic_1024x500.png"

# Generate summary
echo ""
echo "📋 Summary"
echo "=========="
echo ""
echo "Assets saved to: $ASSETS_DIR"
echo ""
echo "✅ What you have:"
if [ -d "$SCREENSHOTS_DIR" ] && [ "$(ls -A $SCREENSHOTS_DIR)" ]; then
    echo "   - $(ls $SCREENSHOTS_DIR | wc -l) screenshot(s)"
fi
if [ -f "$GRAPHICS_DIR/app_icon_512x512.png" ]; then
    echo "   - App icon"
fi
echo ""
echo "📝 What you still need:"
echo "   - Feature graphic (1024x500) - create manually"
echo "   - App icon resized to exactly 512x512 (if needed)"
echo "   - At least 2 screenshots (phone)"
echo ""
echo "🔗 Next Steps:"
echo "1. Check screenshots are good quality and show app features"
echo "2. Create the feature graphic (1024x500)"
echo "3. Ensure app icon is exactly 512x512"
echo "4. Upload all to Google Play Console"
echo ""
echo "For detailed instructions, see: PLAY_STORE_UPLOAD_GUIDE.md"
echo ""
echo "✨ Assets preparation complete!"
