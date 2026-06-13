#!/usr/bin/env bash
set -euo pipefail

HELPER_LABEL="com.coolboard.Helper"
HELPER_TARGET="/Library/PrivilegedHelperTools/${HELPER_LABEL}"
PLIST_TARGET="/Library/LaunchDaemons/${HELPER_LABEL}.plist"

sudo launchctl bootout system "$PLIST_TARGET" >/dev/null 2>&1 || true
sudo rm -f "$HELPER_TARGET" "$PLIST_TARGET"

echo "Removed ${HELPER_LABEL}."
