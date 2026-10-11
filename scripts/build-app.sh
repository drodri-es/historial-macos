#!/bin/zsh
set -euo pipefail

cd "${0:A:h}/.."
app_path="$PWD/dist/Historial.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
mkdir -p "$PWD/.build/module-cache"
swiftc -swift-version 6 -module-cache-path "$PWD/.build/module-cache" \
  Sources/Historial/*.swift -o "$app_path/Contents/MacOS/Historial"
cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>local.historial.clipboard</string>
  <key>CFBundleName</key><string>Historial</string>
  <key>CFBundleDisplayName</key><string>Historial</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>es</string></array>
  <key>CFBundleExecutable</key><string>Historial</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
cp -R Sources/Historial/Resources/*.lproj "$app_path/Contents/Resources/"
codesign --force --sign - "$app_path"
print "Built $app_path"
