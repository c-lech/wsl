#!/usr/bin/env bash
# savetmux — Save every pane of the current tmux session

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
        say_saved "$out"
    else
        echo "savetmux: pane ${win}.${idx} capture failed" >&2
        exit 1
    fi
done