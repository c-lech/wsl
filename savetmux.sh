#!/usr/bin/env bash
# savetmux - save the full text of EVERY pane in your tmux session to saved/logs/.
#
#   savetmux         # -> pane_<session>_0_140526_260914.txt,
#                     #    pane_<session>_1_140526_260914.txt, ... (one per pane)
#
# Grabs the full scroll-back of each pane. Same naming as savepane.
#
# Requires: running inside tmux.
# Exit codes: 0 = saved, 1 = not in tmux or save failed.

set -uo pipefail

usage() { awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 && !/^#/ {exit}' "$0"; exit 0; }

if [ "${1:-}" = "-h" ]; then usage; fi

if [ -z "${TMUX:-}" ]; then
    echo "savetmux: run me inside tmux" >&2
    exit 1
fi

dir="$HOME/projects/saved/logs"
mkdir -p "$dir" || exit 1

stamp="$(date +%H%M%S)_$(date +%y%m%d)"
sid="$(tmux display-message -p '#{session_name}')"
sid="${sid// /_}"

mapfile -t panes < <(tmux list-panes -F '#{window_index}.#{pane_index}')

[ "${#panes[@]}" -gt 0 ] || { echo "savetmux: no panes found" >&2; exit 1; }

for p in "${panes[@]}"; do
    win="${p%%.*}"
    idx="${p#*.}"
    out="$dir/pane_${sid}_${idx}_${stamp}.txt"
    [ -e "$out" ] && out="$dir/pane_${sid}_${win}_${idx}_${stamp}.txt"
    if tmux capture-pane -t "${sid}:${win}.${idx}" -p -S - > "$out"; then
        echo "saved: $out"
    else
        echo "savetmux: pane ${win}.${idx} capture failed" >&2
        exit 1
    fi
done