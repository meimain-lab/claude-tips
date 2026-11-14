#!/bin/sh
# Build the menu bar app and assemble build/Claude Tips.app with an ad-hoc signature.
# Needs only the Command Line Tools (swift build); no Xcode project.
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
package_dir="$repo_dir/menubar"
app_dir="$repo_dir/build/Claude Tips.app"
version=$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' "$repo_dir/pane/.claude-plugin/plugin.json" | head -n 1)
version=${version:-0.1.0}

python3 "$repo_dir/scripts/validate-tips.py" "$repo_dir/content/tips.json"

swift build -c release --package-path "$package_dir"
binary="$(swift build -c release --package-path "$package_dir" --show-bin-path)/ClaudeTipsMenuBar"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary" "$app_dir/Contents/MacOS/ClaudeTipsMenuBar"
# Bundled fallback copy, used when ~/.claude/claude-tips/tips.json is missing.
cp "$repo_dir/content/tips.json" "$app_dir/Contents/Resources/tips.json"
# App icon for Finder, Login Items and permission dialogs; the menu bar keeps its SF Symbol.
"$repo_dir/scripts/make-app-icon.sh" "$app_dir/Contents/Resources/AppIcon.icns"

cat > "$app_dir/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>zh-Hans</string>
  <key>CFBundleExecutable</key><string>ClaudeTipsMenuBar</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIdentifier</key><string>io.github.claude-tips.menubar</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>Claude Tips</string>
  <key>CFBundleDisplayName</key><string>Claude Tips</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleVersion</key><string>$version</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$app_dir"
codesign --verify --verbose=1 "$app_dir"
echo "已生成：$app_dir"
