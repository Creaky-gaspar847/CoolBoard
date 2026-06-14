#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CoolBoard"
BUNDLE_ID="com.coolboard.CoolBoard"
APP_VERSION="0.1.1"
MIN_SYSTEM_VERSION="14.0"
HELPER_NAME="CoolBoardHelper"
HELPER_LABEL="com.coolboard.Helper"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$DIST_DIR/release"
RELEASE_WORK_DIR="$(mktemp -d "/tmp/${APP_NAME}.release.XXXXXX")"
PKG_ROOT="$RELEASE_WORK_DIR/pkg-root"
PKG_SCRIPTS="$RELEASE_WORK_DIR/pkg-scripts"
APP_INSTALL_DIR="$PKG_ROOT/Applications"
APP_BUNDLE="$APP_INSTALL_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_HELPERS="$APP_CONTENTS/Library/LaunchServices"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
HELPER_BINARY="$APP_HELPERS/$HELPER_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_NAME="CoolBoard"
ICON_FILE="$ICON_NAME.icns"
ICON_SOURCE="$ROOT_DIR/Sources/CoolBoard/Resources/$ICON_FILE"
PKG_PATH="$RELEASE_DIR/${APP_NAME}-macOS-Apple-Silicon.pkg"
LEGACY_ZIP_PATH="$RELEASE_DIR/${APP_NAME}-macOS-Apple-Silicon.zip"

VERIFY_DIR=""
cleanup() {
  rm -rf "$RELEASE_WORK_DIR"
  if [[ -n "$VERIFY_DIR" ]]; then
    rm -rf "$VERIFY_DIR"
  fi
}
trap cleanup EXIT

cd "$ROOT_DIR"
mkdir -p "$ROOT_DIR/.build/module-cache" "$ROOT_DIR/.build/swiftpm-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
export SWIFTPM_CACHE_PATH="$ROOT_DIR/.build/swiftpm-cache"
export COPYFILE_DISABLE=1
export DITTONORSRC=1

swift test
swift build -c release --product "$APP_NAME"
swift build -c release --product "$HELPER_NAME"

BUILD_DIR="$(swift build -c release --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"
BUILD_HELPER="$BUILD_DIR/$HELPER_NAME"

rm -rf "$PKG_ROOT" "$PKG_SCRIPTS" "$PKG_PATH" "$LEGACY_ZIP_PATH" "$RELEASE_DIR/$APP_NAME" "$RELEASE_DIR/pkg-root" "$RELEASE_DIR/pkg-scripts"
mkdir -p "$APP_MACOS" "$APP_HELPERS" "$APP_RESOURCES" "$PKG_SCRIPTS"

cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$BUILD_HELPER" "$HELPER_BINARY"
chmod +x "$HELPER_BINARY"

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "missing app icon: $ICON_SOURCE" >&2
  exit 1
fi
cp "$ICON_SOURCE" "$APP_RESOURCES/$ICON_FILE"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>$ICON_NAME</string>
  <key>CFBundleIconName</key>
  <string>$ICON_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

cat >"$PKG_SCRIPTS/preinstall" <<'PREINSTALL'
#!/bin/bash
set -euo pipefail

HELPER_LABEL="com.coolboard.Helper"
TARGET_VOLUME="${3:-/}"

if [[ "$TARGET_VOLUME" == "/" ]]; then
  PLIST_TARGET="/Library/LaunchDaemons/${HELPER_LABEL}.plist"
  /bin/launchctl bootout system "$PLIST_TARGET" >/dev/null 2>&1 || true
fi

exit 0
PREINSTALL

cat >"$PKG_SCRIPTS/postinstall" <<'POSTINSTALL'
#!/bin/bash
set -euo pipefail

APP_NAME="CoolBoard"
HELPER_NAME="CoolBoardHelper"
HELPER_LABEL="com.coolboard.Helper"
TARGET_VOLUME="${3:-/}"

if [[ "$TARGET_VOLUME" == "/" ]]; then
  ROOT_PREFIX=""
else
  ROOT_PREFIX="$TARGET_VOLUME"
fi

APP_BUNDLE="${ROOT_PREFIX}/Applications/${APP_NAME}.app"
HELPER_SOURCE="${APP_BUNDLE}/Contents/Library/LaunchServices/${HELPER_NAME}"
HELPER_TARGET="${ROOT_PREFIX}/Library/PrivilegedHelperTools/${HELPER_LABEL}"
PLIST_TARGET="${ROOT_PREFIX}/Library/LaunchDaemons/${HELPER_LABEL}.plist"

if [[ ! -x "$HELPER_SOURCE" ]]; then
  echo "Missing helper binary: $HELPER_SOURCE" >&2
  exit 1
fi

/bin/mkdir -p "${ROOT_PREFIX}/Library/PrivilegedHelperTools" "${ROOT_PREFIX}/Library/LaunchDaemons"
/usr/bin/install -o root -g wheel -m 755 "$HELPER_SOURCE" "$HELPER_TARGET"

/bin/cat > "$PLIST_TARGET" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${HELPER_LABEL}</string>
  <key>MachServices</key>
  <dict>
    <key>${HELPER_LABEL}</key>
    <true/>
  </dict>
  <key>ProgramArguments</key>
  <array>
    <string>${HELPER_TARGET}</string>
    <string>--xpc-service</string>
  </array>
  <key>RunAtLoad</key>
  <false/>
  <key>KeepAlive</key>
  <false/>
  <key>StandardErrorPath</key>
  <string>/var/log/coolboard-helper.err.log</string>
  <key>StandardOutPath</key>
  <string>/var/log/coolboard-helper.out.log</string>
</dict>
</plist>
PLIST

/usr/sbin/chown root:wheel "$PLIST_TARGET"
/bin/chmod 644 "$PLIST_TARGET"

if [[ "$TARGET_VOLUME" == "/" ]]; then
  /bin/launchctl bootout system "$PLIST_TARGET" >/dev/null 2>&1 || true
  /bin/launchctl bootstrap system "$PLIST_TARGET" || true
  /bin/launchctl enable "system/${HELPER_LABEL}" || true
fi

exit 0
POSTINSTALL

chmod +x "$PKG_SCRIPTS/preinstall" "$PKG_SCRIPTS/postinstall"

if command -v xattr >/dev/null 2>&1; then
  xattr -c -r "$APP_BUNDLE"
  xattr -c -r "$PKG_SCRIPTS"
fi

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1
fi

clean_app_bundle="$RELEASE_WORK_DIR/${APP_NAME}.clean.app"
rm -rf "$clean_app_bundle"
ditto --norsrc --noextattr --noqtn --noacl "$APP_BUNDLE" "$clean_app_bundle"
rm -rf "$APP_BUNDLE"
ditto --norsrc --noextattr --noqtn --noacl "$clean_app_bundle" "$APP_BUNDLE"

if command -v xattr >/dev/null 2>&1; then
  xattr -c -r "$APP_BUNDLE"
fi

find "$PKG_ROOT" "$PKG_SCRIPTS" \( -name ".DS_Store" -o -name "._*" \) -delete

pkgbuild_log="$RELEASE_WORK_DIR/pkgbuild.log"
if ! pkgbuild \
  --root "$PKG_ROOT" \
  --scripts "$PKG_SCRIPTS" \
  --identifier "${BUNDLE_ID}.installer" \
  --version "$APP_VERSION" \
  --install-location "/" \
  --filter '.*\.DS_Store$' \
  --filter '.*\._.*$' \
  --filter '(^|/)\.svn($|/)' \
  --filter '(^|/)CVS($|/)' \
  "$PKG_PATH" > /dev/null 2>"$pkgbuild_log"; then
  cat "$pkgbuild_log" >&2
  exit 1
fi

VERIFY_DIR="$(mktemp -d "/tmp/${APP_NAME}.verify.XXXXXX")"

if command -v pkgutil >/dev/null 2>&1; then
  payload_files="$(pkgutil --payload-files "$PKG_PATH" 2>/dev/null)"
  if ! printf '%s\n' "$payload_files" | grep -qx "^\./Applications/${APP_NAME}\.app/Contents/MacOS/${APP_NAME}$"; then
    echo "pkg payload does not contain ${APP_NAME}.app executable" >&2
    exit 1
  fi
  if ! printf '%s\n' "$payload_files" | grep -qx "^\./Applications/${APP_NAME}\.app/Contents/Library/LaunchServices/${HELPER_NAME}$"; then
    echo "pkg payload does not contain ${HELPER_NAME}" >&2
    exit 1
  fi

  expanded_pkg="$RELEASE_WORK_DIR/pkg-expanded"
  rm -rf "$expanded_pkg"
  pkgutil --expand-full "$PKG_PATH" "$expanded_pkg" >/dev/null 2>&1
  if find "$expanded_pkg/Payload" \( -name ".DS_Store" -o -name "._*" \) -print -quit | grep -q .; then
    echo "expanded pkg payload contains Finder metadata files" >&2
    exit 1
  fi
fi

ditto "$APP_BUNDLE" "$VERIFY_DIR/$APP_NAME.app"
if command -v xattr >/dev/null 2>&1; then
  xattr -c -r "$VERIFY_DIR/$APP_NAME.app"
fi
if command -v codesign >/dev/null 2>&1; then
  codesign --verify --deep --strict --verbose=2 "$VERIFY_DIR/$APP_NAME.app" >/dev/null 2>&1
fi

echo "$PKG_PATH"
