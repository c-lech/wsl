#!/usr/bin/env bash
# savepane - save the full text of your current tmux pane to saved/logs/.
#
#   savepane         # -> ~/shared/saved/logs/pane_<session>_<pane>_140526_260914.txt
#
# Grabs the full scroll-back of the pane you're in. Same naming as savetmux,
# but for one pane only.
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

dir="$HOME/shared/saved/logs"
mkdir -p "$dir" || exit 1

sid="$(tmux display-message -p '#{session_name}')"
idx="$(tmux display-message -p '#{pane_index}')"
sid="${sid// /_}"

out="$dir/pane_${sid}_${idx}_$(date +%H%M%S)_$(date +%y%m%d).txt"

tmux capture-pane -p -S - > "$out"

echo "saved: $out"
