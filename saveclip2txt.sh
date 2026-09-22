#!/usr/bin/env bash
# saveclip2txt — Save Windows-clipboard text

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

say_saved() {                                # clickable 3-line 'saved:' block; plain when piped
  if [ -t 1 ]; then
    local uri dir_win
    uri="file:///$(wslpath -m "$1")"          # Windows path -> Ctrl+click opens
    dir_win="$(wslpath -m "$(dirname "$1")")"
    printf '\e]8;;%s\e\\saved: %s\e]8;;\e\\\n'        "$uri" "$(basename "$1")"
    printf '\e]8;;file:///%s/\e\\folder: %s\e]8;;\e\\\n' "$dir_win" "$dir_win"
    printf '\e]8;;%s\e\\%s\e]8;;\e\\\n'              "$uri" "$1"
  else
    echo "saved: $1"
  fi
}

if [ "${1:-}" = "-h" ]; then usage; fi

text="$(powershell.exe -NoProfile -STA -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Clipboard]::GetText()" 2>/dev/null | tr -d '\r')"

[ -z "$text" ] && { echo "saveclip2txt: clipboard is empty" >&2; exit 1; }

dir="$HOME/shared/saved"
mkdir -p "$dir" || exit 1

stamp="$(date +%y%m%d_%H%M%S)"
out="$dir/${stamp}_txt.txt"
printf '%s\n' "$text" > "$out"

say_saved "$out"
