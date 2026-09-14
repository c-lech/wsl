#!/usr/bin/env bash
# savecmd - run a command and save its output to saved/logs/.
#
#   savecmd systemctl status zabbix-agent
#
# stdout goes to the file, errors stay on your screen as usual.
# File naming: cmd_<HHMMSS>_<yymmdd>.txt

set -uo pipefail

if [ $# -eq 0 ]; then
    echo "savecmd: give me a command to run" >&2
    exit 1
fi

dir="$HOME/projects/saved/logs"
mkdir -p "$dir" || exit 1

out="$dir/cmd_$(date +%H%M%S)_$(date +%y%m%d).txt"

"$@" | tee "$out"

echo "saved: $out"