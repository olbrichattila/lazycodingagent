#!/usr/bin/env bash
# Copy assets/ (splash image, etc.) next to the built executable ($TargetDir).
set -euo pipefail
PROJ_DIR="${1:?project dir}"
TARGET_DIR="${2:?target dir}"
SRC="${PROJ_DIR}/assets"
DEST="${TARGET_DIR}/assets"
if [ ! -d "$SRC" ]; then
  echo "copy-assets: missing ${SRC}" >&2
  exit 0
fi
rm -rf "$DEST"
cp -r "$SRC" "$DEST"
