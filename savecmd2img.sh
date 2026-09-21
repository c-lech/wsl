#!/usr/bin/env bash

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

echo "saved: $out"
