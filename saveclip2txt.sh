#!/usr/bin/env bash

set -uo pipefail

usage() {
  cat <<'EOF'
saveclip2txt — Save Windows-clipboard text

Usage:
  saveclip2txt [OPTIONS]

Options:
  -h    Show this help

Examples:
  saveclip2txt    # -> ~/shared/saved/260921_143022_txt.txt

Notes:
  Reads clipboard text only; images are ignored.
  File naming: yymmdd_HHMMSS_txt.txt.
  Exit codes: 0 = saved, 1 = clipboard is empty.
EOF
  exit 0
}

if [ "${1:-}" = "-h" ]; then usage; fi

text="$(powershell.exe -NoProfile -STA -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Clipboard]::GetText()" 2>/dev/null | tr -d '\r')"

[ -z "$text" ] && { echo "saveclip2txt: clipboard is empty" >&2; exit 1; }

dir="$HOME/shared/saved"
mkdir -p "$dir" || exit 1

stamp="$(date +%y%m%d_%H%M%S)"
out="$dir/${stamp}_txt.txt"
printf '%s\n' "$text" > "$out"

echo "saved: $out"
