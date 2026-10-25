#!/bin/zsh
# Builds a universal MemoryBar.app and MemoryBar-<version>.dmg next to this script.
# Pass "install" to also copy the app into /Applications and relaunch it.
set -e
cd "$(dirname "$0")"
VERSION=1.0
APP=MemoryBar.app
rm -rf $APP build stage
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources build
cp AppIcon.icns $APP/Contents/Resources/
swiftc -O -target arm64-apple-macos13 MemoryBar.swift -o build/MemoryBar-arm64
swiftc -O -target x86_64-apple-macos13 MemoryBar.swift -o build/MemoryBar-x86_64
lipo -create build/MemoryBar-arm64 build/MemoryBar-x86_64 -output $APP/Contents/MacOS/MemoryBar
cat > $APP/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>MemoryBar</string>
<key>CFBundleDisplayName</key><string>MemoryBar</string>
<key>CFBundleIdentifier</key><string>com.simon.memorybar</string>
<key>CFBundleExecutable</key><string>MemoryBar</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>NSHumanReadableCopyright</key><string>© Simon Appleton / Pocket Giant · https://pocketgiant.games/</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - $APP
mkdir stage && cp -R $APP stage/ && ln -s /Applications stage/Applications
hdiutil create -volname MemoryBar -srcfolder stage -ov -format UDZO MemoryBar-$VERSION.dmg >/dev/null
rm -rf stage build
echo "Built $APP and MemoryBar-$VERSION.dmg"

if [[ "$1" == "install" ]]; then
  pkill -x MemoryBar || true
  rm -rf /Applications/$APP
  ditto $APP /Applications/$APP
  open /Applications/$APP
  echo "Installed /Applications/$APP"
fi
