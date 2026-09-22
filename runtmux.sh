#!/usr/bin/env bash
# runtmux - open a NEW tmux session with N panes. Never kills anything.
#
# Every run creates a brand-new session (named p<N>, p<N>-2, p<N>-3, ...).
# Existing sessions are never touched; close them yourself when finished.

set -euo pipefail

SESSION_PREFIX="p"

usage() {
  cat <<'EOF'
runtmux — Open a new tmux session with N panes

Usage:
  runtmux [OPTIONS] [N]

Options:
  -h    Show this help

Examples:
  runtmux          # plain tmux (same as "runtmux 1")
  runtmux 5        # new session p5, tiled grid of 5 panes
  runtmux 3        # big-left + 2-stack layout

Notes:
  Creates a brand-new session (p<N>, p<N>-2, ...) every run; existing
  sessions are never touched. N = 1..16. Inside tmux it switches, else attaches.
  Exit codes: 0 = ok, 2 = bad N.
EOF
  exit 0
}

if [ "${1:-}" = "-h" ]; then usage; fi

N="${1:-1}"

[[ "$N" =~ ^[0-9]+$ ]] || {
    echo "runtmux: N must be a number between 1 and 16, got '${1:-}'" >&2
    exit 2
}

((N >= 1 && N <= 16)) || {
    echo "runtmux: N must be between 1 and 16, got $N" >&2
    exit 2
}

# Plain tmux: tmux2 == tmux == tmux2 1
if ((N == 1)); then
    exec tmux
fi

# Pick a session name that isn't already in use.
NAME="${SESSION_PREFIX}${N}"
i=1
while tmux has-session -t "=${NAME}" 2>/dev/null; do
    i=$((i + 1))
    NAME="${SESSION_PREFIX}${N}-${i}"
done

tmux new-session -d -s "$NAME" -c "$PWD"
P0=$(tmux display-message -p -t "$NAME" '#{pane_id}')

# Build N panes: each time split the biggest pane along its longest side,
# so no pane ever gets split while it's too small for tmux to handle.
for ((i = 2; i <= N; i++)); do
    best_p="" best_w=0 best_h=0
    while IFS=';' read -r w h p; do
        if (( (w > h ? w : h) > (best_w > best_h ? best_w : best_h) )); then
            best_w=$w
            best_h=$h
            best_p=$p
        fi
    done < <(tmux list-panes -t "$NAME" -F '#{pane_width};#{pane_height};#{pane_id}')

    opt=-h
    ((best_h >= best_w)) && opt=-v
    tmux split-window "$opt" -t "$best_p" -c "$PWD" || {
        echo "runtmux: can't fit $N panes in this terminal" >&2
        break
    }
done

# Layout: tiled grid for all counts; N=3 -> big left + 2-stack.
if ((N == 3)); then
    tmux select-layout -t "$NAME" main-vertical
    W=$(tmux display-message -p -t "$NAME" '#{window_width}')
    tmux resize-pane -t "$P0" -x "$((W * 66 / 100))"
else
    tmux select-layout -t "$NAME" tiled
fi

tmux select-pane -t "$P0"

if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$NAME"
else
    tmux attach-session -t "$NAME"
fi