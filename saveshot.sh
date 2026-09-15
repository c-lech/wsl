#!/usr/bin/env bash
# saveshot - run a command and save a styled terminal screenshot as PNG in saved/images/.
#
#   saveshot hostname
#   saveshot systemctl status zabbix-agent
#
# Uses termshot to render the output as a clean PNG image.
#
# File naming: shot_<HHMMSS>_<yymmdd>.png
# Exit codes: 0 = saved, 1 = no command given or render failed.

set -uo pipefail

usage() { awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 && !/^#/ {exit}' "$0"; exit 0; }

if [ "${1:-}" = "-h" ]; then usage; fi

if [ $# -eq 0 ]; then
    echo "saveshot: give me a command to run" >&2
    exit 1
fi

dir="$HOME/shared/saved/images"
mkdir -p "$dir" || exit 1

out="$dir/shot_$(date +%H%M%S)_$(date +%y%m%d).png"

if ! termshot --filename "$out" -- "$@"; then
    rm -f "$out"
    echo "saveshot: render failed" >&2
    exit 1
fi

[ -s "$out" ] || { echo "saveshot: render failed (no output)" >&2; exit 1; }

echo "saved: $out"
