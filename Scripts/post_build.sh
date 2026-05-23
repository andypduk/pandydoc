#!/bin/bash
# Post-build script to disable sandbox
# Add to Xcode target: Build Phases → Run Script

ENTITLEMENTS_FILE="${SRCROOT}/DocManager/Resources/PandyDoc.entitlements"
BUILT_PRODUCTS_DIR="${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}"

if [ -f "$ENTITLEMENTS_FILE" ] && [ -d "$BUILT_PRODUCTS_DIR" ]; then
    codesign --force --sign - --entitlements "$ENTITLEMENTS_FILE" "$BUILT_PRODUCTS_DIR"
    echo "Re-signed $BUILT_PRODUCTS_DIR with sandbox disabled"
fi
