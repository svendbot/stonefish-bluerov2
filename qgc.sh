#!/usr/bin/env bash
# Launch QGroundControl from inside the stonefish-jazzy distrobox.
# First run extracts the AppImage (we don't have FUSE in the container).
set -euo pipefail

QGC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/qgc"
APPIMAGE="$QGC_DIR/QGroundControl.AppImage"
APPRUN="$QGC_DIR/squashfs-root/AppRun"

if [ ! -f "$APPIMAGE" ]; then
  echo "ERROR: $APPIMAGE missing. Re-download from"
  echo "  https://github.com/mavlink/qgroundcontrol/releases"
  exit 1
fi

if [ ! -x "$APPRUN" ]; then
  echo "==> first run — extracting AppImage"
  ( cd "$QGC_DIR" && ./QGroundControl.AppImage --appimage-extract >/dev/null )
fi

exec "$APPRUN" "$@"
