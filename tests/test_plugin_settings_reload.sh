#!/bin/bash
set -euo pipefail

PLUGIN_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEMP_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEMP_ROOT"' EXIT
cp "$PLUGIN_ROOT/tests/plugin-settings.qml" "$TEMP_ROOT/shell.qml"
cp "$PLUGIN_ROOT/settings.example.toml" "$TEMP_ROOT/settings.toml"
QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
  BTOP_PLUGIN_ROOT="$PLUGIN_ROOT" BTOP_TEST_SETTINGS="$TEMP_ROOT/settings.toml" \
  timeout 10s quickshell --no-color -p "$TEMP_ROOT/shell.qml" >"$TEMP_ROOT/log" 2>&1 || {
    cat "$TEMP_ROOT/log"
    exit 1
  }
grep -F 'ok - plugin settings live reload' "$TEMP_ROOT/log"
