#!/usr/bin/env bash
# Print directory containing lazycodingagent after lazbuild (Linux/macOS CI and packaging).
set -euo pipefail

EXE_NAME=lazycodingagent
PROJECT_ROOT="$(cd "${1:-.}" && pwd)"
EXPLICIT="${2:-}"
CONTEXT="${3:-resolve-lazycodingagent-output}"

has_exe() {
  [[ -f "$1/$EXE_NAME" ]]
}

if [[ -n "$EXPLICIT" ]]; then
  EXPLICIT="$(cd "$EXPLICIT" && pwd)"
  if has_exe "$EXPLICIT"; then
    echo "$EXPLICIT"
    exit 0
  fi
  echo "$CONTEXT: missing $EXPLICIT/$EXE_NAME" >&2
  exit 1
fi

candidates=()
if command -v fpc >/dev/null 2>&1; then
  candidates+=("$PROJECT_ROOT/lib/$(fpc -iTP)-$(fpc -iTO)")
fi
candidates+=("$PROJECT_ROOT/lib/x86_64-linux" "$PROJECT_ROOT")

for dir in "${candidates[@]}"; do
  if has_exe "$dir"; then
    echo "$(cd "$dir" && pwd)"
    exit 0
  fi
done

echo "$CONTEXT: $EXE_NAME not found under $PROJECT_ROOT (run lazbuild first)" >&2
exit 1
