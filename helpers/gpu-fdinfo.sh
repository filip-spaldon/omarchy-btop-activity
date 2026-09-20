#!/bin/bash
set -euo pipefail

proc_root=${BTOP_GPU_PROC_ROOT:-/proc}
dri_root=${BTOP_GPU_DRI_ROOT:-/dev/dri}
script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
declare -a files=()

shopt -s nullglob
command -v python3 >/dev/null 2>&1 || exit 0

devices=("$dri_root"/card[0-9]* "$dri_root"/renderD[0-9]*)
((${#devices[@]})) || exit 0
saw_process=0
for process in "$proc_root"/[0-9]*; do
  [[ -O $process && -d $process/fd ]] && { saw_process=1; break; }
done
((saw_process)) || exit 0

# A proc fd directory can disappear between FTS opening and restatting it,
# causing find's tight cycle hash to remove the directory twice and abort.
# Match DRM nodes by device and inode without traversing proc through FTS.
while IFS= read -r -d '' file; do
  files+=("$file")
done < <(python3 "$script_dir/gpu-fdinfo.py" "$proc_root" "$dri_root")

# Keep counters between refreshes in QML instead of sleeping in the collector.
{
  read -r uptime _ <"$proc_root/uptime"
  printf 'begin\t%s\n' "$uptime"
  if ((${#files[@]})); then
    printf '%s\0' "${files[@]}" |
      xargs -0 -r grep -H -E '^drm-(client-id|pdev|engine-|cycles-|total-cycles-|maxfreq-)' \
        -- 2>/dev/null || true
  fi
  read -r uptime _ <"$proc_root/uptime"
  printf 'end\t%s\n' "$uptime"
} | awk -v wanted="$*" -f "$script_dir/gpu-fdinfo.awk"
