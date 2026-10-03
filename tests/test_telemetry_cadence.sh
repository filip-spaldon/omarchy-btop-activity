#!/bin/bash
set -euo pipefail

PLUGIN_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEMP_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEMP_ROOT"' EXIT
mkdir "$TEMP_ROOT/lib"
cp "$PLUGIN_ROOT/Telemetry.qml" "$TEMP_ROOT/Telemetry.qml"
cp "$PLUGIN_ROOT/lib/Telemetry.js" "$TEMP_ROOT/lib/Telemetry.js"
cp "$PLUGIN_ROOT/tests/telemetry-cadence.qml" "$TEMP_ROOT/shell.qml"
QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
  timeout 8s quickshell --no-color -p "$TEMP_ROOT/shell.qml" >"$TEMP_ROOT/log" 2>&1 || {
    cat "$TEMP_ROOT/log"
    exit 1
  }
grep -F 'ok - CPU RAM and GPU share the selected polling interval' "$TEMP_ROOT/log"
