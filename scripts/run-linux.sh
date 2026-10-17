#!/usr/bin/env bash
# Run LazyCodingAgent on Linux; on Wayland + GTK2 builds, prefer XWayland for GDK.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXE="$ROOT/lazycodingagent"

if [[ ! -x "$EXE" ]]; then
  echo "Missing executable: $EXE (run lazbuild lazycodingagent.lpi first)" >&2
  exit 1
fi

if [[ "${XDG_SESSION_TYPE:-}" == wayland ]] && [[ -z "${GDK_BACKEND:-}" ]]; then
  export GDK_BACKEND=x11
fi

exec "$EXE" "$@"
