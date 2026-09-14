#!/usr/bin/env bash
# savetxt - save whatever is on the Windows clipboard as txt in saved/logs/.
#
#   savetxt           # -> ~/projects/saved/logs/txt_143022_260914.txt
#
# Reads clipboard text only. Images are ignored.

set -uo pipefail

text="$(powershell.exe -NoProfile -STA -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Clipboard]::GetText()" 2>/dev/null | tr -d '\r')"

[ -z "$text" ] && { echo "savetxt: clipboard is empty" >&2; exit 1; }

dir="$HOME/projects/saved/logs"
mkdir -p "$dir" || exit 1

out="$dir/txt_$(date +%H%M%S)_$(date +%y%m%d).txt"
printf '%s\n' "$text" > "$out"

echo "saved: $out"