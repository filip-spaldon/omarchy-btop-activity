#!/bin/bash
set -euo pipefail

[[ $# -eq 2 && ( $2 == create || $2 == edit ) ]] || exit 2
settings=$1
plugin_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

# Only the user-owned copy is editable; plugin updates replace the template.
if [[ $2 == create && ! -e $settings && ! -L $settings ]]; then
  mkdir -p -- "$(dirname -- "$settings")"
  (umask 077; set -o noclobber; cat "$plugin_root/settings.example.toml" >"$settings")
fi
[[ -f $settings && -r $settings ]] || {
  printf 'Cannot read plugin settings: %s\n' "$settings" >&2
  exit 1
}
if [[ $2 == edit ]]; then
  exec omarchy launch config-editor "$settings"
fi
