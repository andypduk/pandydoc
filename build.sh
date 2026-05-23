#!/bin/bash
set -e

BUILD_DIR=".build/debug"
APP_NAME="PandyDoc"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building $APP_NAME..."
swift build --product "$APP_NAME"
echo "Building SaveToPandyDoc..."
swift build --product SaveToPandyDoc

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "$BUILD_DIR/SaveToPandyDoc" "$APP_BUNDLE/Contents/MacOS/"

cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>PandyDoc</string>
    <key>CFBundleIconFile</key>
    <string>PandaIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.pandydoc.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>PandyDoc</string>
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

cp Resources/PandaIcon.icns "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true

echo "App bundle created at: $APP_BUNDLE"
echo "Launching..."
open "$APP_BUNDLE"
