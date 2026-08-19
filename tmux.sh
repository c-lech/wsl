#!/usr/bin/env bash
set -euo pipefail

SESSION="main"
USER="root"

IPS=(
    "192.168.56.111"
    "192.168.56.111"
    "192.168.56.111"
    "192.168.56.111"
    "192.168.56.111"
    "192.168.56.111"
)

((${#IPS[@]} == 6)) || {
    echo "Error: exactly 6 IPs required" >&2
    exit 1
}

tmux kill-session -t "$SESSION" 2>/dev/null || true

tmux new-session -d -s "$SESSION"

P0=$(tmux display-message -p '#{pane_id}')

# Make the right column
tmux split-window -h -t "$P0"
P1=$(tmux display-message -p '#{pane_id}')

# Four equal panes on the right
tmux split-window -v -t "$P1"
P2=$(tmux display-message -p '#{pane_id}')

tmux split-window -v -t "$P2"
P3=$(tmux display-message -p '#{pane_id}')

tmux split-window -v -t "$P3"
P4=$(tmux display-message -p '#{pane_id}')

# NOW split the original left pane
tmux split-window -v -t "$P0"
P5=$(tmux display-message -p '#{pane_id}')

PANES=("$P0" "$P5" "$P1" "$P2" "$P3" "$P4")

# Set the left/right width exactly like your original script
WIDTH=$(tmux display-message -p -t "$P0" '#{window_width}')
tmux resize-pane -t "$P0" -x $((WIDTH * 66 / 100))

# The right side is now exactly the same 4-pane stack as before.
# Make the new bottom-left pane the same height as one right pane.
HEIGHT=$(tmux display-message -p -t "$P1" '#{pane_height}')
tmux resize-pane -t "$P5" -y "$HEIGHT"

# SSH
for i in "${!PANES[@]}"; do
    tmux respawn-pane -k -t "${PANES[$i]}" \
        "ssh ${USER}@${IPS[$i]}"
done

tmux select-pane -t "$P0"

if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$SESSION"
else
    tmux attach-session -t "$SESSION"
fi
