#!/usr/bin/env bash
# Install Qt5 Lazarus build deps and compile lazycodingagent for Linux release (DEB / AppImage).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ "${CI_LINUX_QT5_SKIP_APT:-0}" != "1" ]]; then
  echo "ci-linux-qt5-release-build: installing apt packages..."
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends \
    git fpc lazarus lcl fp-units-rtl fp-units-fcl fp-units-misc \
    libqt5pas-dev qtbase5-dev \
    dpkg-dev file wget curl xvfb \
    libglib2.0-dev libgdk-pixbuf2.0-dev libxml2-dev libxslt1-dev
fi

ensure_qt5_units_writable() {
  local units_root qt5_dir user group
  user="${SUDO_USER:-${USER:-runner}}"
  group="$(id -gn "$user" 2>/dev/null || echo "$user")"

  for units_root in /usr/lib/lazarus/*/units/x86_64-linux /usr/share/lazarus/*/units/x86_64-linux; do
    [[ -d "$(dirname "$units_root")" ]] || continue
    qt5_dir="${units_root}/qt5"
    if [[ ! -d "$qt5_dir" ]]; then
      echo "ci-linux-qt5-release-build: creating writable $qt5_dir"
      sudo install -d -o "$user" -g "$group" "$qt5_dir"
    elif [[ ! -w "$qt5_dir" ]]; then
      echo "ci-linux-qt5-release-build: fixing ownership on $qt5_dir"
      sudo chown -R "$user:$group" "$qt5_dir"
    fi
    return 0
  done

  echo "ci-linux-qt5-release-build: warning: no /usr/share/lazarus/*/units/x86_64-linux found" >&2
}

ensure_qt5_units_writable

chmod +x "$SCRIPT_DIR"/*.sh

export LCL_WIDGETSET=qt5

"$SCRIPT_DIR/ci-prepare-lazarus-deps.sh"
"$SCRIPT_DIR/install-lca-lazarus.sh" --link-only --widgetset=qt5

cd "$ROOT"
LCL_WIDGETSET=qt5 "$SCRIPT_DIR/ci-lazbuild.sh" lazycodingagent.lpi

LIB_DIR="$ROOT/lib/$(fpc -iTP)-$(fpc -iTO)"
mkdir -p "$LIB_DIR"
BUILD_OUT="$("$SCRIPT_DIR/resolve-lazycodingagent-output.sh" "$ROOT" "" ci-linux-qt5-release-build)"
if [[ "$BUILD_OUT" != "$(cd "$LIB_DIR" && pwd)" ]]; then
  install -m 755 "$BUILD_OUT/lazycodingagent" "$LIB_DIR/lazycodingagent"
fi
"$SCRIPT_DIR/post-build.sh" "$ROOT" "$LIB_DIR"

TARGET_DIR="$LIB_DIR"
BIN="$TARGET_DIR/lazycodingagent"
if [[ ! -f "$BIN" ]]; then
  echo "ci-linux-qt5-release-build: missing $BIN" >&2
  exit 1
fi

if ! ldd "$BIN" | grep -q 'libQt5Core'; then
  echo "ci-linux-qt5-release-build: binary does not link Qt5:" >&2
  ldd "$BIN" >&2 || true
  exit 1
fi

echo "ci-linux-qt5-release-build: OK ($BIN links Qt5)"
