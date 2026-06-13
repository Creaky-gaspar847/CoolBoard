#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER_LABEL="com.coolboard.Helper"
HELPER_TARGET="/Library/PrivilegedHelperTools/${HELPER_LABEL}"
PLIST_TARGET="/Library/LaunchDaemons/${HELPER_LABEL}.plist"
PLIST_TMP="$(mktemp "/tmp/${HELPER_LABEL}.plist.XXXXXX")"

cleanup() {
  rm -f "$PLIST_TMP"
}
trap cleanup EXIT

cd "$ROOT_DIR"
swift build -c release --product CoolBoardHelper

cat > "$PLIST_TMP" <<PLIST
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

sudo mkdir -p /Library/PrivilegedHelperTools
sudo install -o root -g wheel -m 755 ".build/release/CoolBoardHelper" "$HELPER_TARGET"
sudo install -o root -g wheel -m 644 "$PLIST_TMP" "$PLIST_TARGET"

sudo launchctl bootout system "$PLIST_TARGET" >/dev/null 2>&1 || true
sudo launchctl bootstrap system "$PLIST_TARGET"
sudo launchctl enable "system/${HELPER_LABEL}"

echo "Installed ${HELPER_LABEL}."
echo "Manual fan writes will use the privileged XPC helper after the app is restarted."
