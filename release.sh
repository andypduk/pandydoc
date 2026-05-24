#!/bin/bash
set -e

# Configuration
APP_NAME="PandyDoc"
TEAM_ID="9QT6FF55Y2"
APPLE_ID="asdennisuk@gmail.com"
APP_SPECIFIC_PASSWORD="kwqe-qxdy-yqwa-vjyw"
DEVELOPER_ID="0297483EBF599BBC283CA59C3BB40957569D9779"
BUILD_DIR=".build/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_FILE="dist/$APP_NAME.dmg"

echo "=== Building $APP_NAME (Release) ==="

# Clean and build
echo "Building $APP_NAME..."
swift build --product "$APP_NAME" -c release
echo "Building SaveToPandyDoc..."
swift build --product SaveToPandyDoc -c release

# Create app bundle
echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "$BUILD_DIR/SaveToPandyDoc" "$APP_BUNDLE/Contents/MacOS/"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>PandaHead</string>
    <key>CFBundleIdentifier</key>
    <string>com.pandydoc.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2026 PandyDoc. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Copy resources
cp Resources/PandaHead.icns "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true
cp Resources/PandaHead.pdf "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true

echo "=== Code Signing ==="

# Sign all dylibs and frameworks first (inner to outer)
echo "Signing embedded binaries..."
find "$APP_BUNDLE" -type f \( -name "*.dylib" -o -name "*.so" \) -exec codesign --force --options runtime --sign "$DEVELOPER_ID" --timestamp {} \;

# Sign the SaveToPandyDoc helper
echo "Signing SaveToPandyDoc..."
codesign --force --options runtime --sign "$DEVELOPER_ID" --timestamp "$APP_BUNDLE/Contents/MacOS/SaveToPandyDoc"

# Sign the main app
echo "Signing $APP_NAME..."
codesign --force --options runtime --sign "$DEVELOPER_ID" --timestamp "$APP_BUNDLE"

# Verify signature
echo "Verifying signature..."
codesign --verify --deep --strict "$APP_BUNDLE" && echo "✅ Signature valid" || echo "❌ Signature verification failed"

echo "=== Creating DMG ==="

mkdir -p dist
rm -f "$DMG_FILE"

# Create a temporary directory for the DMG contents
DMG_SRC="dist/dmg-src"
rm -rf "$DMG_SRC"
mkdir -p "$DMG_SRC"
cp -R "$APP_BUNDLE" "$DMG_SRC/"

# Create symlink to /Applications
ln -s /Applications "$DMG_SRC/Applications"

# Create DMG
echo "Creating DMG..."
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_SRC" -ov -format UDZO "$DMG_FILE"

# Clean up temp directory
rm -rf "$DMG_SRC"

echo "✅ DMG created: $DMG_FILE"

echo "=== Notarization ==="

# Submit for notarization
echo "Submitting for notarization..."
NOTARIZATION_OUTPUT=$(xcrun notarytool submit "$DMG_FILE" \
    --apple-id "$APPLE_ID" \
    --password "$APP_SPECIFIC_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait 2>&1) || true

echo "$NOTARIZATION_OUTPUT"

# Check if notarization succeeded
if echo "$NOTARIZATION_OUTPUT" | grep -q "status: Accepted"; then
    echo "✅ Notarization successful"
    
    # Staple the notarization ticket
    echo "Stapling notarization ticket..."
    xcrun stapler staple "$APP_BUNDLE"
    xcrun stapler staple "$DMG_FILE"
    echo "✅ Ticket stapled"
else
    echo "❌ Notarization failed or timed out"
    echo "Check status with:"
    echo "  xcrun notarytool log <submission-id> --apple-id $APPLE_ID --password $APP_SPECIFIC_PASSWORD --team-id $TEAM_ID"
    exit 1
fi

echo ""
echo "=== Build Complete ==="
echo "DMG: $DMG_FILE"
echo "Ready for distribution!"
