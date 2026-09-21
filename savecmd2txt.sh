#!/usr/bin/env bash

set -uo pipefail

usage() {
  cat <<'EOF'
savecmd2txt — Run a command and save its output as plain text

Usage:
  savecmd2txt [OPTIONS] COMMAND [ARGS...]

Options:
  -h    Show this help

Examples:
  savecmd2txt hostname
  savecmd2txt systemctl status zabbix-agent

Notes:
  stdout stays on screen with colors; ANSI escapes are stripped from the file.
  File naming: yymmdd_HHMMSS_cmd.txt.
  Exit codes: 0 = saved, 1 = no command given, else the command's exit code.
EOF
  exit 0
}

if [ "${1:-}" = "-h" ]; then usage; fi

if [ $# -eq 0 ]; then
    echo "savecmd2txt: give me a command to run" >&2
    exit 1
fi

dir="$HOME/shared/saved"
mkdir -p "$dir" || exit 1

stamp="$(date +%y%m%d_%H%M%S)"
out="$dir/${stamp}_cmd.txt"

"$@" | tee "$out"

rc=${PIPESTATUS[0]}
sed -i \
  -e 's/\x1b\[[0-9;?]*[ -/]*[@-~]//g' \
  -e 's/\x1b\][^\x1b\x0a]*\(\x07\|\x1b\\\)//g' \
  -e 's/\x1b[G_P][^\x1b]*\(\x1b\\\)//g' \
  -e 's/\x1b\\//g' \
  "$out"

if [ "$rc" -ne 0 ]; then
  rm -f "$out"
  echo "savecmd2txt: command failed (exit $rc) - nothing saved" >&2
  exit "$rc"
fi

echo "saved: $out"
