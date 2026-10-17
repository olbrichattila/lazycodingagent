#!/usr/bin/env bash
# Install pinned FPC + Lazarus from SourceForge for GitHub Actions (Homebrew cask is disabled).
set -euo pipefail

# Pinned to Lazarus macOS aarch64 / Lazarus 4.8 on SourceForge.
SF_BASE="https://downloads.sourceforge.net/project/lazarus/Lazarus%20macOS%20aarch64/Lazarus%204.8"
FPC_DMG="fpc-3.2.4rc1a.intelarm64-macosx.dmg"
LAZARUS_ZIP="lazarus-darwin-aarch64-4.8.zip"

WORKDIR="${CI_LAZARUS_WORKDIR:-${RUNNER_TEMP:-/tmp}/lazarus-ci}"
LAZARUS_INSTALL="${CI_LAZARUS_ROOT:-$WORKDIR/lazarus-tree}"
mkdir -p "$WORKDIR"

download() {
  local url="$1" dest="$2"
  if [[ -f "$dest" ]]; then
    return 0
  fi
  curl -fL --retry 3 --retry-delay 5 -o "$dest" "$url"
}

echo "ci-install-lazarus-macos: installing FPC from $FPC_DMG"
FPC_PATH="$WORKDIR/$FPC_DMG"
download "$SF_BASE/$FPC_DMG" "$FPC_PATH"

FPC_MOUNT="$WORKDIR/fpc-mount"
mkdir -p "$FPC_MOUNT"
hdiutil attach "$FPC_PATH" -mountpoint "$FPC_MOUNT" -nobrowse -quiet
FPC_PKG="$(find "$FPC_MOUNT" -maxdepth 2 -name '*.pkg' -print -quit)"
if [[ -z "$FPC_PKG" ]]; then
  echo "ci-install-lazarus-macos: no .pkg found in FPC DMG" >&2
  hdiutil detach "$FPC_MOUNT" -quiet || true
  exit 1
fi
sudo installer -pkg "$FPC_PKG" -target /
hdiutil detach "$FPC_MOUNT" -quiet

echo "ci-install-lazarus-macos: installing Lazarus from $LAZARUS_ZIP"
ZIP_PATH="$WORKDIR/$LAZARUS_ZIP"
download "$SF_BASE/$LAZARUS_ZIP" "$ZIP_PATH"
xattr -cr "$ZIP_PATH"
rm -rf "$LAZARUS_INSTALL"
mkdir -p "$LAZARUS_INSTALL"
unzip -q "$ZIP_PATH" -d "$LAZARUS_INSTALL"

LAZBUILD_BIN="$(find "$LAZARUS_INSTALL" -name lazbuild -type f -print -quit)"
if [[ -z "$LAZBUILD_BIN" ]]; then
  echo "ci-install-lazarus-macos: lazbuild not found under $LAZARUS_INSTALL" >&2
  exit 1
fi
LAZARUS_ROOT="$(cd "$(dirname "$LAZBUILD_BIN")" && pwd)"
LAZBUILD_BIN="$LAZARUS_ROOT/lazbuild"

if [[ ! -x "$LAZBUILD_BIN" ]]; then
  chmod +x "$LAZBUILD_BIN"
fi

"$LAZBUILD_BIN" --version

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "LAZARUS_DIR=$LAZARUS_ROOT"
    echo "LAZBUILD=$LAZBUILD_BIN"
    echo "LCL_WIDGETSET=cocoa"
    echo "PATH=$LAZARUS_ROOT:/usr/local/bin:${PATH}"
  } >>"$GITHUB_ENV"
fi

export LAZARUS_DIR="$LAZARUS_ROOT"
export LAZBUILD="$LAZBUILD_BIN"
export LCL_WIDGETSET=cocoa
export PATH="$LAZARUS_ROOT:/usr/local/bin:${PATH}"

echo "ci-install-lazarus-macos: ready (LAZARUS_DIR=$LAZARUS_ROOT)"
