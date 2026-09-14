#!/usr/bin/env bash
# savepane - save the full text of your current tmux pane to saved/logs/.
#
#   savepane         # -> ~/projects/saved/logs/pane_140526_260914.txt
#
# Grabs the full scroll-back of the pane you're in.
#
# Requires: running inside tmux.
# Exit codes: 0 = saved, 1 = not in tmux or save failed.

set -uo pipefail

usage() { awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 && !/^#/ {exit}' "$0"; exit 0; }

if [ "${1:-}" = "-h" ]; then usage; fi

if [ -z "${TMUX:-}" ]; then
    echo "savepane: run me inside tmux" >&2
    exit 1
fi

dir="$HOME/projects/saved/logs"
mkdir -p "$dir" || exit 1

out="$dir/pane_$(date +%H%M%S)_$(date +%y%m%d).txt"

tmux capture-pane -p -S - > "$out"

echo "saved: $out"
