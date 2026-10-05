#!/bin/bash
set -euo pipefail

[[ $# -eq 2 ]] || exit 2

mode=$1
config_path=$2

case $mode in
  Floating | Tiled) ;;
  *) exit 2 ;;
esac

send_help_key() {
  local state=$1
  local event
  event="hl.dsp.send_key_state({ mods = \"SHIFT\", key = \"slash\", "
  event+="state = \"$state\", window = \"address:$address\" })"
  hyprctl dispatch "$event" >/dev/null
}

bash "$(dirname -- "${BASH_SOURCE[0]}")/open-btop.sh" "$mode" "$config_path" &

for _ in {1..30}; do
  address=$(hyprctl clients -j | jq -r '
    first(.[] | select(.class == "org.omarchy.btop-activity") | .address) // empty')
  if [[ -n $address ]]; then
    sleep 0.6
    send_help_key down
    sleep 0.05
    send_help_key up
    exit
  fi
  sleep 0.1
done
printf 'The plugin btop window did not appear.\n' >&2
exit 1
