#!/bin/zsh
# Builds Dailies.app + its WidgetKit extension with nothing but Command Line Tools
# (swiftc + codesign). No Xcode project needed.
#
#   ./build.sh            build into ./build/Dailies.app
#   ./build.sh --install  build, copy to /Applications, register widget, launch
#
set -euo pipefail
cd "$(dirname "$0")"

# No Xcode on this Mac: use the Command Line Tools 27 toolchain unpacked into the home dir
# (extracted from Apple's CLT package with pkgutil — no admin rights needed).
if [[ -z "${DEVELOPER_DIR:-}" && -d "$HOME/Developer/CLT27/Library/Developer/CommandLineTools" ]]; then
  export DEVELOPER_DIR="$HOME/Developer/CLT27/Library/Developer/CommandLineTools"
fi
ROOT="$PWD"
BUILD="$ROOT/build"
APP="$BUILD/Dailies.app"
APPEX="$APP/Contents/PlugIns/DailiesWidget.appex"
TMP="$BUILD/tmp"

APP_ID="com.yahya.dailies"
WIDGET_ID="com.yahya.dailies.widget"
MIN_OS="14.0"
VERSION="1.0.0"
BUILD_NUM="$(date +%Y%m%d%H%M)"
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macos${MIN_OS}"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"

SDK="$(xcrun --sdk macosx --show-sdk-path)"
SDK_VER="$(xcrun --sdk macosx --show-sdk-version)"
SWIFTC="$(xcrun -f swiftc)"

echo "▸ swiftc : $("$SWIFTC" --version 2>&1 | head -1)"
echo "▸ SDK    : $SDK ($SDK_VER)"
echo "▸ target : $TARGET"

rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APPEX/Contents/MacOS" "$APPEX/Contents/Resources" "$TMP"

SHARED=( "$ROOT"/Sources/Shared/*.swift )
APP_SHARED=( ${SHARED:#*Intents.swift} )      # the app never performs intents itself
COMMON=( -O -swift-version 5 -parse-as-library -target "$TARGET" -sdk "$SDK" -suppress-warnings )

# ── 1. App ───────────────────────────────────────────────────────────────────────
echo "▸ compiling app…"
"$SWIFTC" "${COMMON[@]}" -module-name Dailies \
  "${APP_SHARED[@]}" "$ROOT"/Sources/App/*.swift \
  -framework SwiftUI -framework AppKit -framework WidgetKit -framework AppIntents \
  -framework UserNotifications -framework ServiceManagement -framework Combine \
  -o "$APP/Contents/MacOS/Dailies"

# ── 2. Widget extension ─────────────────────────────────────────────────────────
echo "▸ compiling widget extension…"
"$SWIFTC" "${COMMON[@]}" -D WIDGET_EXTENSION -application-extension -module-name DailiesWidget \
  "${SHARED[@]}" "$ROOT"/Sources/Widget/*.swift \
  -framework SwiftUI -framework WidgetKit -framework AppIntents \
  -Xlinker -e -Xlinker _NSExtensionMain \
  -o "$APPEX/Contents/MacOS/DailiesWidget"

# ── 3. App Intents metadata (lets the widget's check buttons run ToggleGameIntent) ──
META="$APPEX/Contents/Resources/Metadata.appintents"
mkdir -p "$META"
# The exact mangled type name, as the compiler emitted it (word substitutions included): the
# AppIntents runtime matches it byte for byte against the metadata below.
MANGLED="$(nm "$APPEX/Contents/MacOS/DailiesWidget" | grep -o '\$s[A-Za-z0-9_]*IntentVMa$' | head -1 | sed 's/^\$s//; s/Ma$//')"
[[ -n "$MANGLED" ]] || { echo "✗ could not find the intent type in the widget binary" >&2; exit 1; }
python3 - "$META" "$MANGLED" <<'PY'
import json, sys, os
meta = sys.argv[1]
mangled = sys.argv[2]
action = {
  "assistantDefinedSchemas": [], "assistantDefinedSchemaTraits": [],
  "authenticationPolicy": 0,
  "availabilityAnnotations": {"LNPlatformNameWildcard": {"introducedVersion": "*"}},
  "descriptionMetadata": {"descriptionText": {"alternatives": [], "key": "Marks one of your daily games as done (or not done)."}, "searchKeywords": []},
  "effectiveBundleIdentifiers": [],
  "fullyQualifiedTypeName": "DailiesWidget.ToggleGameIntent",
  "identifier": "ToggleGameIntent",
  "isAuthPolExplicit": False, "isDiscoverable": False,
  "mangledTypeName": mangled,
  "mangledTypeNameByBundleIdentifier": {}, "mangledTypeNameByBundleIdentifierV2": {},
  "mangledTypeNameV2": mangled,
  "openAppWhenRun": False, "outputFlags": 0,
  "parameters": [{
    "capabilities": 0, "dynamicOptionsSupport": 0, "inputConnectionBehavior": 0,
    "isInput": False, "isOptional": False, "name": "gameID", "resolvableInputTypes": [{"kindValue": 0, "valueType": {"primitive": {"wrapper": {"typeIdentifier": 12}}}}, {"kindValue": 0, "valueType": {"primitive": {"wrapper": {"typeIdentifier": 0}}}}],
    "title": {"alternatives": [], "key": "Game ID"}, "typeSpecificMetadata": [],
    "valueType": {"primitive": {"wrapper": {"typeIdentifier": 12}}}
  }],
  "presentationStyle": 0, "requiredCapabilities": [], "supportedModes": 1,
  "systemProtocolMetadata": [], "systemProtocolMetadataV2": [], "systemProtocols": [],
  "title": {"alternatives": [], "key": "Toggle Daily Game"},
  "typeSpecificMetadata": [],
  "visibilityMetadata": {"assistantOnly": False, "isDiscoverable": False}
}
doc = {
  "actions": {"ToggleGameIntent": action},
  "assistantEntities": [], "assistantIntentNegativePhrases": [], "assistantIntents": [], "autoShortcuts": [],
  "entities": {}, "enums": [], "generator": {"name": "xcode-tools", "version": "27A200c"},
  "negativePhrases": [], "queries": {}, "shortcutTileColor": 14, "version": 1
}
json.dump(doc, open(os.path.join(meta, "extract.actionsdata"), "w"), indent=2)
json.dump({"toolsVersion": "27A200c", "version": "3.0"}, open(os.path.join(meta, "version.json"), "w"), indent=2)
PY

# ── 4. Info.plists ──────────────────────────────────────────────────────────────
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleExecutable</key><string>Dailies</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundleIdentifier</key><string>$APP_ID</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>CFBundleName</key><string>Dailies</string>
	<key>CFBundleDisplayName</key><string>Dailies</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>$VERSION</string>
	<key>CFBundleVersion</key><string>$BUILD_NUM</string>
	<key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
	<key>DTPlatformName</key><string>macosx</string>
	<key>DTPlatformVersion</key><string>$SDK_VER</string>
	<key>DTSDKName</key><string>macosx$SDK_VER</string>
	<key>LSMinimumSystemVersion</key><string>$MIN_OS</string>
	<key>LSApplicationCategoryType</key><string>public.app-category.games</string>
	<key>NSHighResolutionCapable</key><true/>
	<key>NSPrincipalClass</key><string>NSApplication</string>
	<key>NSHumanReadableCopyright</key><string>Dailies — your puzzle ritual</string>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key><string>$APP_ID</string>
			<key>CFBundleURLSchemes</key><array><string>dailies</string></array>
		</dict>
	</array>
</dict>
</plist>
PLIST

cat > "$APPEX/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleExecutable</key><string>DailiesWidget</string>
	<key>CFBundleIdentifier</key><string>$WIDGET_ID</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>CFBundleName</key><string>DailiesWidget</string>
	<key>CFBundleDisplayName</key><string>Dailies</string>
	<key>CFBundlePackageType</key><string>XPC!</string>
	<key>CFBundleShortVersionString</key><string>$VERSION</string>
	<key>CFBundleVersion</key><string>$BUILD_NUM</string>
	<key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
	<key>DTPlatformName</key><string>macosx</string>
	<key>DTPlatformVersion</key><string>$SDK_VER</string>
	<key>DTSDKName</key><string>macosx$SDK_VER</string>
	<key>LSMinimumSystemVersion</key><string>$MIN_OS</string>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key><string>com.apple.widgetkit-extension</string>
	</dict>
</dict>
</plist>
PLIST

# ── 5. Icon ─────────────────────────────────────────────────────────────────────
if [[ ! -f "$ROOT/Resources/AppIcon.icns" ]]; then
  echo "▸ rendering icon…"
  swift "$ROOT/Resources/MakeIcon.swift" "$TMP/icon1024.png"
  ICONSET="$TMP/AppIcon.iconset"; mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$TMP/icon1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    d=$((s*2)); sips -z $d $d "$TMP/icon1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$ROOT/Resources/AppIcon.icns"
fi
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
for art in "$ROOT"/Resources/Faces/face-idle.png "$ROOT"/Resources/Faces/face-half.png \
           "$ROOT"/Resources/Faces/face-goal.png "$ROOT"/Resources/Faces/face-crazed.png \
           "$ROOT"/Resources/Art/yayas-space.png; do
  cp "$art" "$APP/Contents/Resources/"
  cp "$art" "$APPEX/Contents/Resources/"
done
echo "APPL????" > "$APP/Contents/PkgInfo"

# ── 6. Sign (ad-hoc). The widget is sandboxed (required for extensions) with a file exception
#      for ~/Library/Application Support/Dailies; the app itself runs unsandboxed. ─────────────
echo "▸ signing…"
codesign --force --sign - --identifier "$WIDGET_ID" --entitlements "$ROOT/Resources/Widget.entitlements" "$APPEX"
codesign --force --sign - --identifier "$APP_ID" "$APP"
codesign --verify --deep --strict "$APP"
echo "✓ built $APP"

# ── 7. Install ──────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--install" ]]; then
  DEST="$INSTALL_DIR/Dailies.app"
  echo "▸ installing to $DEST…"
  osascript -e 'tell application id "com.yahya.dailies" to quit' >/dev/null 2>&1 || true
  # chronod keeps talking to whichever widget process is alive — kill stale ones (e.g. from an
  # earlier launch out of ./build) and drop their registrations, or the desktop keeps the old code.
  pkill -f "DailiesWidget.appex/Contents/MacOS/DailiesWidget" >/dev/null 2>&1 || true
  pluginkit -r "$APPEX" >/dev/null 2>&1 || true
  sleep 1
  rm -rf "$DEST"
  ditto "$APP" "$DEST"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST" >/dev/null 2>&1 || true
  pluginkit -a "$DEST/Contents/PlugIns/DailiesWidget.appex" >/dev/null 2>&1 || true
  open -g "$DEST"
  echo "✓ installed + launched. Widget: right-click desktop → Edit Widgets → search “Dailies”."
fi
