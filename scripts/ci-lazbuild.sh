#!/usr/bin/env bash
# lazbuild wrapper for CI (macOS SourceForge tree): correct LazarusDir and primary config.
set -euo pipefail

LAZBUILD="${LAZBUILD:-lazbuild}"
args=()

if [[ -n "${LAZARUS_DIR:-}" && -n "${LAZARUS_PRIMARY_CONFIG:-}" ]]; then
  args+=(--lazarusdir="$LAZARUS_DIR" --primary-config-path="$LAZARUS_PRIMARY_CONFIG")
fi

if [[ -n "${LCL_WIDGETSET:-}" ]]; then
  args+=(--widgetset="$LCL_WIDGETSET")
fi

exec "$LAZBUILD" "${args[@]}" "$@"
