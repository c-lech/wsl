#!/usr/bin/env bash
# saveshot - run a command and save a styled terminal screenshot as PNG in saved/images/.
#
#   saveshot hostname
#   saveshot systemctl status zabbix-agent
#
# Uses termshot to render the output as a clean PNG image.
# File naming: shot_<HHMMSS>_<yymmdd>.png

set -uo pipefail

if [ $# -eq 0 ]; then
    echo "saveshot: give me a command to run" >&2
    exit 1
fi

dir="$HOME/projects/saved/images"
mkdir -p "$dir" || exit 1

out="$dir/shot_$(date +%H%M%S)_$(date +%y%m%d).png"

termshot --filename "$out" -- "$@"

echo "saved: $out"