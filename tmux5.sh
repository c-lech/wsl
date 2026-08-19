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
)

((${#IPS[@]} == 5)) || {
    echo "Error: exactly 5 IPs required" >&2
    exit 1
}

tmux kill-session -t "$SESSION" 2>/dev/null || true

tmux new-session -d -s "$SESSION"

P0=$(tmux display-message -p '#{pane_id}')

tmux split-window -h -t "$P0"
P1=$(tmux display-message -p '#{pane_id}')

tmux split-window -v -t "$P1"
P2=$(tmux display-message -p '#{pane_id}')

tmux split-window -v -t "$P2"
P3=$(tmux display-message -p '#{pane_id}')

tmux split-window -v -t "$P3"
P4=$(tmux display-message -p '#{pane_id}')

PANES=("$P0" "$P1" "$P2" "$P3" "$P4")

# Finish layout before starting SSH.
tmux select-layout -t "$SESSION" main-vertical

WIDTH=$(tmux display-message -p -t "$P0" '#{window_width}')
tmux resize-pane -t "$P0" -x $((WIDTH * 66 / 100))

# Start one SSH process directly in each pane.
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
