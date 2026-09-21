#!/usr/bin/env bash

set -uo pipefail

usage() {
  cat <<'EOF'
savetmux — Save every pane of the current tmux session

Usage:
  savetmux [OPTIONS]

Options:
  -h    Show this help

Examples:
  savetmux      # -> ~/shared/saved/260921_143022_tmux_<sess>_<win>_<idx>.txt

Notes:
  Grabs the full scroll-back of every pane; 1 pane = 1 file, N panes = N files.
  Naming is time-ordered, so ls is chronological.
  Requires: running inside tmux.
  Exit codes: 0 = saved, 1 = not in tmux or save failed.
EOF
  exit 0
}

if [ "${1:-}" = "-h" ]; then usage; fi

if [ -z "${TMUX:-}" ]; then
    echo "savetmux: run me inside tmux" >&2
    exit 1
fi

dir="$HOME/shared/saved"
mkdir -p "$dir" || exit 1

stamp="$(date +%y%m%d_%H%M%S)"
sid="$(tmux display-message -p '#{session_name}')"
sid="${sid// /_}"

mapfile -t panes < <(tmux list-panes -F '#{window_index}.#{pane_index}')

[ "${#panes[@]}" -gt 0 ] || { echo "savetmux: no panes found" >&2; exit 1; }

for p in "${panes[@]}"; do
    win="${p%%.*}"
    idx="${p#*.}"
    out="$dir/${stamp}_tmux_${sid}_${win}_${idx}.txt"
    if tmux capture-pane -t "${sid}:${win}.${idx}" -p -S - > "$out"; then
        echo "saved: $out"
    else
        echo "savetmux: pane ${win}.${idx} capture failed" >&2
        exit 1
    fi
done