#!/usr/bin/env bash
# Copy in-app help/ next to the built executable ($TargetDir).
set -euo pipefail
PROJ_DIR="${1:?project dir}"
TARGET_DIR="${2:?target dir}"
SRC="${PROJ_DIR}/help"
DEST="${TARGET_DIR}/help"
if [ ! -d "$SRC" ]; then
  echo "copy-help: missing ${SRC}" >&2
  exit 0
fi
rm -rf "$DEST"
cp -r "$SRC" "$DEST"
