#!/bin/bash
set -euo pipefail

PLUGIN_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEMP_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEMP_ROOT"' EXIT
mkdir -p "$TEMP_ROOT/bin"
export EDITOR_LOG="$TEMP_ROOT/editor.log"
cat >"$TEMP_ROOT/bin/omarchy" <<'MOCK'
#!/bin/bash
printf '%s\n' "$@" >"$EDITOR_LOG"
MOCK
chmod 0755 "$TEMP_ROOT/bin/omarchy"
export PATH="$TEMP_ROOT/bin:$PATH"
settings="$TEMP_ROOT/user config/omarchy/ilyazar.btop/settings.toml"

# Opening a missing file must not create it without consent.
if bash "$PLUGIN_ROOT/helpers/plugin-settings.sh" "$settings" edit 2>"$TEMP_ROOT/error"; then
  printf 'missing settings were opened without consent\n' >&2
  exit 1
fi
[[ ! -e $settings && ! -e $EDITOR_LOG ]]

bash "$PLUGIN_ROOT/helpers/plugin-settings.sh" "$settings" create
cmp "$PLUGIN_ROOT/settings.example.toml" "$settings"
[[ $(stat -c '%a' "$settings") == 600 && ! -e $EDITOR_LOG ]]
bash "$PLUGIN_ROOT/helpers/plugin-settings.sh" "$settings" edit
printf 'launch\nconfig-editor\n%s\n' "$settings" >"$TEMP_ROOT/expected"
cmp "$TEMP_ROOT/expected" "$EDITOR_LOG"

# Opening an existing file must preserve edits, even invalid ones.
printf 'left_click = "unfinished' >"$settings"
cp "$settings" "$TEMP_ROOT/saved"
bash "$PLUGIN_ROOT/helpers/plugin-settings.sh" "$settings" create
bash "$PLUGIN_ROOT/helpers/plugin-settings.sh" "$settings" edit
cmp "$TEMP_ROOT/saved" "$settings"

# User-managed symlinks remain intact.
mv "$settings" "$TEMP_ROOT/linked"
ln -s "$TEMP_ROOT/linked" "$settings"
bash "$PLUGIN_ROOT/helpers/plugin-settings.sh" "$settings" edit
[[ -L $settings ]]
cmp "$TEMP_ROOT/saved" "$TEMP_ROOT/linked"

printf 'ok - plugin settings editor\n'
