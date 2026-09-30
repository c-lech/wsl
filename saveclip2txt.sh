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

say_saved() {                                # clickable 2-line block; plain when piped
  if [ -t 1 ]; then
    local uri dir_win
    uri="file:///$(wslpath -m "$1")"          # Windows path -> Ctrl+click opens
    dir_win="$(wslpath -m "$(dirname "$1")")"
    printf '\e]8;;%s\e\\saved: %s\e]8;;\e\\\n'        "$uri" "$(basename "$1")"
    printf '\e]8;;file:///%s/\e\\folder: %s\e]8;;\e\\\n' "$dir_win" "$dir_win"
  else
    echo "saved: $1"
  fi
}

if [ "${1:-}" = "-h" ]; then usage; fi

dir="$HOME/shared/saved"
mkdir -p "$dir" || exit 1

stamp="$(date +%y%m%d_%H%M%S)"
out="$dir/${stamp}_txt.txt"

powershell.exe -NoProfile -STA -Command "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Clipboard]::GetText()" 2>/dev/null | tr -d '\r' > "$out"

[ -s "$out" ] || { rm -f "$out"; echo "saveclip2txt: clipboard is empty" >&2; exit 1; }

say_saved "$out"

notify_saved() {                             # toast: rendered-card preview + Open; never fails the save
  local win_txt rows win_temp card card_win
  win_txt="$(wslpath -w "$out" 2>/dev/null || true)"
  [ -n "$win_txt" ] || return 0
  rows="Saved text|$(basename "$out")"
  card=""
  win_temp="$(wslpath "$(powershell.exe -NoProfile -Command '$env:TEMP' 2>/dev/null | tr -d '\r' || true)" 2>/dev/null || true)"
  if [ -n "$win_temp" ] && command -v silicon >/dev/null 2>&1; then
    card="$win_temp/savetxt_card_$$.png"
    rm -f "$card"
    head -c 600 "$out" 2>/dev/null | tr -d '\r' | silicon \
      -l markdown --theme OneHalfDark -b '#282c34' \
      --no-window-controls \
      --shadow-blur-radius 24 --shadow-color '#000000' --shadow-offset-y 8 \
      --pad-horiz 40 --pad-vert 60 -o "$card" >/dev/null 2>&1 || true
    [ -s "$card" ] || card=""
  fi
  if [ -n "$card" ]; then
    card_win="$(wslpath -w "$card" 2>/dev/null || true)"
    [ -n "$card_win" ] && "$HOME/wsl/notifywin.sh" --image "$card_win" --open "$win_txt" --rows "$rows" >/dev/null 2>&1 || true
  else
    "$HOME/wsl/notifywin.sh" --open "$win_txt" --rows "$rows" >/dev/null 2>&1 || true
  fi
}
notify_saved
