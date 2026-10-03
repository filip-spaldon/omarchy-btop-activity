#!/bin/bash

# Close the plugin's btop window when one is open, otherwise launch btop.
#
# The bar widget runs this with both arguments when settings.toml sets
# `left_click = "toggle"`. Bound bare, it makes one key open and close btop:
#
#   hl.unbind("SUPER + CTRL + T")
#   o.bind("SUPER + CTRL + T", "Activity", os.getenv("HOME")
#     .. "/.config/omarchy/plugins/ilyazar.btop/helpers/toggle-btop.sh")

set -euo pipefail

app_id="${1:-}"
config="${2:-}"

if [[ -z $app_id ]]; then
  # Bare invocation: follow the widget's own window mode and runtime config.
  mode=$(jq -r '.. | objects | select(.id? == "ilyazar.btop") | .windowMode // empty' \
    "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json" 2>/dev/null | head -n 1 || true)
  app_id=org.omarchy.btop
  [[ ${mode:-} == Tiled ]] && app_id=org.omarchy.btop_tiled
  runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/omarchy-btop-activity/btop.conf"
  if [[ -f $runtime ]]; then config=$runtime; fi
fi

# Close windows from either mode, so switching Floating/Tiled while btop is
# open cannot strand the window opened under the previous mode.
addresses=$(hyprctl clients -j | jq -r '.[]
  | select(.class == "org.omarchy.btop" or .class == "org.omarchy.btop_tiled")
  | .address')

if [[ -n $addresses ]]; then
  while read -r address; do
    hyprctl dispatch "hl.dsp.window.close({ window = \"address:$address\" })"
  done <<<"$addresses"
  exit 0
fi

launch=(omarchy-launch-or-focus-tui "--app-id=$app_id" btop)
[[ -n $config ]] && launch+=(--config "$config")
exec "${launch[@]}"
