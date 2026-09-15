#!/usr/bin/env bash
# savetxt - save whatever is on the Windows clipboard as txt in saved/logs/.
#
#   savetxt           # -> ~/shared/saved/logs/txt_143022_260914.txt
#
# Reads clipboard text only. Images are ignored.
#
# File naming: txt_<HHMMSS>_<yymmdd>.txt
# Exit codes: 0 = saved, 1 = clipboard is empty.

set -uo pipefail

usage() { awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 && !/^#/ {exit}' "$0"; exit 0; }

if [ "${1:-}" = "-h" ]; then usage; fi

text="$(powershell.exe -NoProfile -STA -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Clipboard]::GetText()" 2>/dev/null | tr -d '\r')"

[ -z "$text" ] && { echo "savetxt: clipboard is empty" >&2; exit 1; }

dir="$HOME/shared/saved/logs"
mkdir -p "$dir" || exit 1

out="$dir/txt_$(date +%H%M%S)_$(date +%y%m%d).txt"
printf '%s\n' "$text" > "$out"

echo "saved: $out"
