#!/usr/bin/env bash
# savepane - save the whole text of your current tmux pane to saved/logs/.
#
#   savepane         # -> ~/projects/saved/logs/log_140526_260914.txt
#
# Grabs the full scroll-back of the pane you're in. Same naming style as
# saveimg.sh/savecode.sh (log_<HHMMSS>_<yymmdd>.txt).
#
# Requires: running inside tmux.

set -uo pipefail

if [ -z "${TMUX:-}" ]; then
    echo "savepane: run me inside tmux" >&2
    exit 1
fi

dir="$HOME/projects/saved/logs"
mkdir -p "$dir" || exit 1

out="$dir/pane_$(date +%H%M%S)_$(date +%y%m%d).txt"

tmux capture-pane -p -S - > "$out"

echo "saved: $out"