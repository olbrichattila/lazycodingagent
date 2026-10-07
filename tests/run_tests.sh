#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TEST_OUTPUT="$(mktemp -d)"
cleanup() { rm -rf "$TEST_OUTPUT"; }
trap cleanup EXIT
LAZARUS_DIR="${LAZARUS_DIR:-}"
if [[ -z "$LAZARUS_DIR" && -d /usr/lib/lazarus ]]; then LAZARUS_DIR=/usr/lib/lazarus; fi
if [[ -z "$LAZARUS_DIR" ]]; then echo "Set LAZARUS_DIR"; exit 1; fi
ARCH="$(uname -m)"
fpc -Mobjfpc -Scghi -Fu"$ROOT" -Fu"$LAZARUS_DIR/components/lazutils/lib/$ARCH-linux" \
  -FU"$TEST_OUTPUT" -FE"$TEST_OUTPUT" tests/tool_driver.lpr
fpc -Mobjfpc -Scghi -Fu"$ROOT" -FU"$TEST_OUTPUT" -FE"$TEST_OUTPUT" tests/test_agent_rules.pas
"$TEST_OUTPUT/test_agent_rules" "$TEST_OUTPUT/rules-fixture"
python3 tests/test_local_tools.py "$TEST_OUTPUT/tool_driver"
echo "All LazyCodingAgent tool tests passed."
