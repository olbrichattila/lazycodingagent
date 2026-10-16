#!/usr/bin/env bash
# Link SynEdit + TurboPower IPro for headless lazbuild (CI or fresh Linux/macOS install).
set -euo pipefail

LAZBUILD="${LAZBUILD:-lazbuild}"
if ! command -v "$LAZBUILD" >/dev/null 2>&1; then
  echo "ci-prepare-lazarus-deps: lazbuild not found (set LAZBUILD)" >&2
  exit 1
fi

link_and_build() {
  local lpk="$1"
  if [[ ! -f "$lpk" ]]; then
    echo "ci-prepare-lazarus-deps: missing $lpk" >&2
    return 1
  fi
  "$LAZBUILD" --add-package-link "$lpk"
  "$LAZBUILD" "$lpk"
}

find_synedit_lpk() {
  local root dir
  for root in \
    "${LAZARUS_DIR:-}" \
    "/usr/lib/lazarus" \
    "/usr/share/lazarus" \
    "/Applications/Lazarus/lazarus" \
    "/Applications/Lazarus" \
    "C:/lazarus" \
    "C:/Program Files/Lazarus" \
    ; do
    [[ -z "$root" ]] && continue
    dir="${root}/components/synedit/synedit.lpk"
    if [[ -f "$dir" ]]; then
      echo "$dir"
      return 0
    fi
  done
  return 1
}

install_turbopower_ipro() {
  local dir="${TURBOPOWER_IPRO_DIR:-${RUNNER_TEMP:-/tmp}/IPro}"
  local lpk=""
  if [[ ! -d "$dir/.git" ]]; then
    rm -rf "$dir"
    git clone --depth 1 https://github.com/TurboPack/IPro.git "$dir"
  fi
  lpk="$(find "$dir" -maxdepth 4 -type f -iname 'turbopoweripro.lpk' 2>/dev/null | head -1 || true)"
  if [[ -z "$lpk" ]]; then
    lpk="$(find "$dir" -maxdepth 4 -type f -name '*.lpk' 2>/dev/null | head -1 || true)"
  fi
  if [[ -z "$lpk" ]]; then
    echo "ci-prepare-lazarus-deps: TurboPower IPro .lpk not found under $dir" >&2
    return 1
  fi
  link_and_build "$lpk"
}

SYNEDIT_LPK="$(find_synedit_lpk)" || {
  echo "ci-prepare-lazarus-deps: SynEdit .lpk not found (set LAZARUS_DIR)" >&2
  exit 1
}
link_and_build "$SYNEDIT_LPK"

DSGN_LPK="$(dirname "$SYNEDIT_LPK")/syneditdsgn.lpk"
if [[ -f "$DSGN_LPK" ]]; then
  link_and_build "$DSGN_LPK"
fi

install_turbopower_ipro
echo "ci-prepare-lazarus-deps: SynEdit and TurboPower IPro linked."
