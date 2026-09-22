#!/usr/bin/env bash
# savecmd2img — Run a command and save its output as a styled terminal image

set -uo pipefail

usage() {
  cat <<'EOF'
savecmd2img — Run a command and save its output as a styled terminal image

Usage:
  savecmd2img [OPTIONS] COMMAND [ARGS...]

Options:
  -h    Show this help

Examples:
  savecmd2img hostname
  savecmd2img systemctl status zabbix-agent

Notes:
  Uses termshot to render the output as a clean image.
  File naming: yymmdd_HHMMSS_cmd.png.
  Exit codes: 0 = saved, 1 = no command given or render failed.
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

if [ $# -eq 0 ]; then
    echo "savecmd2img: give me a command to run" >&2
    exit 1
fi

dir="$HOME/shared/saved"
mkdir -p "$dir" || exit 1

stamp="$(date +%y%m%d_%H%M%S)"
out="$dir/${stamp}_cmd.png"

if ! termshot --filename "$out" -- "$@"; then
    rm -f "$out"
    echo "savecmd2img: render failed" >&2
    exit 1
fi

[ -s "$out" ] || { echo "savecmd2img: render failed (no output)" >&2; exit 1; }

say_saved "$out"
