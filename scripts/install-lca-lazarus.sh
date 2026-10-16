#!/usr/bin/env bash
# Install TerminalEmulator + LCA Design System packages for Lazarus IDE and lazbuild.
set -euo pipefail

LINK_ONLY=0
SKIP_TERMINAL=0
for arg in "$@"; do
  case "$arg" in
    --link-only) LINK_ONLY=1 ;;
    --skip-terminal) SKIP_TERMINAL=1 ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TE="$ROOT/third_party/TerminalEmulator"
LpkTF="$TE/TerminalFramework/TerminalFramework.lpk"
LpkView="$TE/ViewLCL/ViewLCL.lpk"
LpkRuntime="$ROOT/packages/LcaDesignSystem/LcaDesignSystem.lpk"
LpkDesign="$ROOT/packages/LcaDesignSystem/LcaDesignSystemDesign.lpk"

LAZBUILD="${LAZBUILD:-lazbuild}"
if ! command -v "$LAZBUILD" >/dev/null 2>&1; then
  echo "lazbuild not found. Set LAZBUILD to your lazbuild path." >&2
  exit 1
fi

if [[ "$SKIP_TERMINAL" -eq 0 ]]; then
  if [[ ! -f "$LpkTF" ]]; then
    echo "Missing submodule: git submodule update --init third_party/TerminalEmulator" >&2
    exit 1
  fi
  "$LAZBUILD" --add-package-link "$LpkTF"
  "$LAZBUILD" --add-package-link "$LpkView"
  "$LAZBUILD" "$LpkTF"
  "$LAZBUILD" "$LpkView"
fi

"$LAZBUILD" --add-package-link "$LpkRuntime"
"$LAZBUILD" "$LpkRuntime"

if [[ "$LINK_ONLY" -eq 0 ]]; then
  "$LAZBUILD" --add-package "$LpkDesign"
  echo ""
  echo "Close Lazarus completely before rebuilding the IDE (required for the component palette)."
  echo "Rebuilding Lazarus IDE with LcaDesignSystemDesign (runtime stays out of lazarus.exe)..."
  "$LAZBUILD" --build-ide
  echo ""
  echo "IDE rebuild complete. Start Lazarus and open the Component palette page: LCA Design."
  echo "If Lazarus hangs on startup, run: ./scripts/recover-lazarus-ide.sh"
else
  echo "Link-only: runtime packages linked for lazbuild (no IDE design install)."
fi

echo "Done. Open lazycodingagent.lpi in Lazarus or run: lazbuild lazycodingagent.lpi"
