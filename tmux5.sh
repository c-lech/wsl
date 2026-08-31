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

	tmux new-session -d -s "$SESSION" "ssh ${USER}@${IPS[0]}"

	P0=$(tmux display-message -p '#{pane_id}')

	tmux split-window -h -t "$P0" "ssh ${USER}@${IPS[1]}"
	P1=$(tmux display-message -p '#{pane_id}')

	tmux split-window -v -t "$P1" "ssh ${USER}@${IPS[2]}"
	P2=$(tmux display-message -p '#{pane_id}')

	tmux split-window -v -t "$P2" "ssh ${USER}@${IPS[3]}"
	P3=$(tmux display-message -p '#{pane_id}')

	tmux split-window -v -t "$P3" "ssh ${USER}@${IPS[4]}"

	# Finish layout.
	tmux select-layout -t "$SESSION" main-vertical

	WIDTH=$(tmux display-message -p -t "$P0" '#{window_width}')
	tmux resize-pane -t "$P0" -x $((WIDTH * 66 / 100))

	tmux select-pane -t "$P0"

if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$SESSION"
else
    tmux attach-session -t "$SESSION"
fi
