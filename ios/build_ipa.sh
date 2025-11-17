#!/bin/bash
set -e

# Build IPA with explicit generic iOS destination
# This fixes the "Found no destinations" error in CI environments

WORKSPACE="Runner.xcworkspace"
SCHEME="Runner"
CONFIGURATION="Release"
ARCHIVE_PATH="build/Runner.xcarchive"
EXPORT_PATH="build/ipa"
EXPORT_OPTIONS="ExportOptions.plist"

echo "Cleaning previous builds..."
xcodebuild clean -workspace "$WORKSPACE" -scheme "$SCHEME" || true

echo "Building archive with generic iOS destination..."
xcodebuild archive \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=iOS" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  || xcodebuild archive \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=iOS"

echo "Exporting IPA..."
if [ -f "$EXPORT_OPTIONS" ]; then
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS"
else
  echo "Warning: ExportOptions.plist not found, using default options"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportMethod development
fi

echo "IPA build complete!"
ls -lh "$EXPORT_PATH"/*.ipa || find "$EXPORT_PATH" -name "*.ipa"

