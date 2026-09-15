#!/usr/bin/env bash
# enterssh - pick a server and ssh in, fuzzy style. Uses your ssh aliases.
#
#   enterssh                    show menu, pick a server -> ssh
#   enterssh --list             just print the menu (see what it found)
#   enterssh --pane [--layout=X]
#                               pick several servers -> each gets a tmux pane:
#                               even count -> tiled, odd -> big left + stack.
#                               --layout=X overrides: tiled | even-horizontal |
#                               even-vertical | main-vertical
#
#   Tab marks servers; Enter with 2+ marked -> tmux panes automatically
#   (same split rules as --pane). fzf preview pings the highlighted host.
#
# The menu is built from the ssh aliases in ~/.bash_aliases (the same file
# bash reads at shell start). Any `alias name="ssh ..."` line shows up
# automatically. The browser alias (zbx) is skipped, it's not ssh.
#
# Manual entry: "type an IP yourself" -> IP, then a user (Enter = root).
#
# Requires: fzf, tmux (--pane), ping (preview)

set -uo pipefail

ALIASES="${HOME}/.bash_aliases"
[ -f "$ALIASES" ] || ALIASES="${HOME}/shared/infra/bash_aliases/bash_aliases"

command -v fzf >/dev/null 2>&1 || {
    echo "enterssh: fzf is not installed (apt install fzf)" >&2
    exit 1
}

MANUAL="--- type an IP yourself ---"
LAYOUT=""

# name -> the full alias command ("ssh user@host")
declare -A CMDS=()
# name -> just "user@host" for display
declare -A DISP=()

while IFS= read -r line; do
    if [[ "$line" =~ ^alias[[:space:]]+([^=]+)=[\'\"]ssh([^\'\"]*)[\'\"] ]]; then
        name=${BASH_REMATCH[1]// /}
        cmd="ssh${BASH_REMATCH[2]}"
        CMDS[$name]=$cmd
        DISP[$name]=${cmd#ssh }
    fi
done < "$ALIASES"

print_menu() {
    local name maxlen=0
    for name in "${!CMDS[@]}"; do
        ((${#name} > maxlen)) && maxlen=${#name}
    done
    for name in "${!CMDS[@]}"; do
        printf "%-${maxlen}s  %s\n" "$name" "${DISP[$name]}"
    done
}

# Extract the resolvable target (IP/hostname) from a menu line.
#   "zbxserver  root@172.27.76.51" -> 172.27.76.51
#   anything without '@' (the MANUAL row) -> empty
target_of() {
    local line=$1
    local t=${line##*@}
    [[ "$line" == *"@"* ]] && printf '%s' "${t%% *}" || true
}

# fzf preview: live-ping the highlighted host, 1 packet per second.
# Lines accumulate (scrollable, capped at 120) with severity colors and an
# auto-scaled bar; last 20 samples render as a block sparkline.
preview_line() {
    local line=$1 t out rtt rtt_ms hms RESET color C_DIM bars sp bl stats
    t=$(target_of "$line")
    if [ -z "$t" ]; then
        echo "Type an IP yourself"
        echo "  e.g. 10.0.0.5        (user: Enter = root)"
        echo "  e.g. clech@10.0.0.1"
        return 0
    fi
    command -v ping >/dev/null 2>&1 || {
        echo "$t : ping not installed"
        return 0
    }

    RESET=$'\033[0m'
    C_OK=$'\033[32m'
    C_SKIP=$'\033[33m'
    C_FAIL=$'\033[31m'
    C_DIM=$'\033[2m'

    local -a hist=()
    local max_rtt=1 sent=0 ok=0 bars

    while :; do
        sent=$((sent + 1))
        out=$(ping -c 1 -W 1 "$t" 2>&1)
        if printf '%s' "$out" | grep -q 'time='; then
            ok=$((ok + 1))
            rtt=$(printf '%s' "$out" | grep -o 'time=[0-9.]*' | grep -o '[0-9.]*$')
            rtt_ms="${rtt} ms"
            hist+=("$rtt")
            if awk -v r="$rtt" 'BEGIN{exit !(r>=10)}'; then
                color=$C_FAIL
            elif awk -v r="$rtt" 'BEGIN{exit !(r>=1)}'; then
                color=$C_SKIP
            else
                color=$C_OK
            fi
            bar_len=$(awk -v r="$rtt" -v m="$max_rtt" 'BEGIN{l=int(r/m*20); if(l<1)l=1; if(l>20)l=20; print l}')
            bars=$(printf '%*s' "$bar_len" '' | tr ' ' '█')
        else
            rtt=""
            rtt_ms="no reply"
            hist+=("")
            color=$C_FAIL
            bars=""
        fi

        if ((${#hist[@]} > 120)); then
            hist=("${hist[@]:${#hist[@]} - 120}")
        fi

        max_rtt=1
        for h in "${hist[@]}"; do
            [ -n "$h" ] || continue
            if awk -v a="$h" -v b="$max_rtt" 'BEGIN{exit !(a>b)}'; then
                max_rtt=$h
            fi
        done

        hms=$(date +%T)
        loss=$(((sent - ok) * 100 / sent))
        printf '%s%s%s  %s%-9s%s %s%s%s  %s%d of %d · %d%% loss\n' \
            "$C_DIM" "$hms" "$RESET" "$color" "$rtt_ms" "$RESET" \
            "$color" "$bars" "$RESET" "$C_DIM" "$ok" "$sent" "$loss"

        sp=""
        start=$(( ${#hist[@]} > 20 ? ${#hist[@]} - 20 : 0 ))
        for ((i = start; i < ${#hist[@]}; i++)); do
            h=${hist[i]}
            if [ -z "$h" ]; then
                sp+="·"
                continue
            fi
            idx=$(awk -v r="$h" -v m="$max_rtt" 'BEGIN{x=int(r/m*8); if(x>7)x=7; if(x<0)x=0; print x}')
            case "$idx" in
                0) bl="▁" ;;
                1) bl="▂" ;;
                2) bl="▃" ;;
                3) bl="▄" ;;
                4) bl="▅" ;;
                5) bl="▆" ;;
                6) bl="▇" ;;
                7) bl="█" ;;
            esac
            sp+="$bl"
        done

        stats=$(
            printf '%s\n' "${hist[@]}" | sed '/^$/d' |
                awk 'NR==1{min=max=$1} {s+=$1; if($1<min)min=$1; if($1>max)max=$1; n++}
                     END{if(n) printf "%.2f · %.2f · %.2f ms  (min/avg/max)", min, s/n, max}'
        )
        printf '%s%s%s\n' "$C_DIM" "$sp" "$RESET"
        if [ -n "$stats" ]; then
            printf '%s%s%s\n' "$C_DIM" "$stats" "$RESET"
        else
            printf '%sno samples yet%s\n' "$C_DIM" "$RESET"
        fi
        printf '%s── live @ %s ──────────────────────────%s\n' "$C_DIM" "$hms" "$RESET"

        sleep 1
    done
}

manual_connect() {
    local ip user
    read -rp 'IP: ' ip
    [ -n "$ip" ] || exit 1
    read -rp 'User (Enter=root): ' user
    user=${user:-root}
    exec ssh "${user}@${ip}"
}

# Split the current biggest pane along its longest side (same as tmux.sh),
# then pick a layout: even -> tiled, odd -> main-vertical (66% left).
run_panes() {
    local -a lines=("$@")
    local -a cmds=()
    local line name opt side win target P0 W

    for line in "${lines[@]}"; do
        [[ "$line" == "$MANUAL" ]] && continue
        name=${line%%  *}
        cmds+=("${CMDS[$name]:-ssh $name}")
    done
    ((${#cmds[@]})) || return 0

    command -v tmux >/dev/null 2>&1 || {
        echo "enterssh: --pane needs tmux (apt install tmux)" >&2
        return 1
    }

    if [[ -n "${TMUX:-}" ]]; then
        # inside tmux: open a new window (detached), leave current work alone
        win=$(tmux display-message -p '#{window_id}')
        tmux new-window -d -n ssh -c "$PWD" "exec ${cmds[0]}"
        P0=$(tmux display-message -p -t "$win" '#{pane_id}')
        target="$win"
    else
        # outside tmux: fresh session named sshfarm (auto-increment)
        name="sshfarm"
        i=1
        while tmux has-session -t "=$name" 2>/dev/null; do
            name="sshfarm$((i++))"
        done
        tmux new-session -d -s "$name" -c "$PWD" "exec ${cmds[0]}"
        P0=$(tmux display-message -p -t "$name" '#{pane_id}')
        target="$name"
    fi

    for ((i = 1; i < ${#cmds[@]}; i++)); do
        best_p="" best_w=0 best_h=0
        while IFS=';' read -r w h p; do
            if (( (w > h ? w : h) > (best_w > best_h ? best_w : best_h) )); then
                best_w=$w
                best_h=$h
                best_p=$p
            fi
        done < <(tmux list-panes -t "$target" -F '#{pane_width};#{pane_height};#{pane_id}')

        opt=-h
        ((best_h >= best_w)) && opt=-v
        tmux split-window "$opt" -t "$best_p" -c "$PWD" "exec ${cmds[i]}" || break
    done

    if ((${#cmds[@]} > 1)); then
        if [[ -n "$LAYOUT" ]]; then
            tmux select-layout -t "$target" "$LAYOUT"
        elif (( ${#cmds[@]} % 2 == 0 )); then
            tmux select-layout -t "$target" tiled
        else
            tmux select-layout -t "$target" main-vertical
            W=$(tmux display-message -p -t "$P0" '#{window_width}')
            tmux resize-pane -t "$P0" -x "$((W * 66 / 100))"
        fi
    fi

    tmux select-pane -t "$P0"
    if [[ -n "${TMUX:-}" ]]; then
        tmux select-window -t "$target"
    else
        tmux attach-session -t "$name"
    fi
}

# --- internal: fzf preview helper --------------------------------------
if [ "${1:-}" = "--_preview" ]; then
    preview_line "${2:-}"
    exit 0
fi

# --- internal: run panes from given menu lines (no fzf) -----------------
if [ "${1:-}" = "--_pane" ]; then
    shift
    run_panes "$@"
    exit $?
fi

MODE=""
case "${1:-}" in
    --list)
        print_menu | sort
        printf '%s\n' "$MANUAL"
        exit 0
        ;;
    --pane)
        MODE=pane
        shift
        ;;
esac

case "${1:-}" in
    --layout=*)
        LAYOUT=${1#--layout=}
        shift
        ;;
    --layout)
        [ $# -ge 2 ] || { echo "enterssh: --layout needs a value" >&2; exit 2; }
        LAYOUT=$2
        shift 2
        ;;
esac
if [ -n "$LAYOUT" ]; then
    [[ " tiled even-horizontal even-vertical main-vertical " == *" $LAYOUT "* ]] || {
        echo "enterssh: bad layout '$LAYOUT' (tiled|even-horizontal|even-vertical|main-vertical)" >&2
        exit 2
    }
fi

if [ ! -f "$ALIASES" ]; then
    echo "enterssh: no ssh aliases found (looked at ${HOME}/.bash_aliases or ~/shared/infra/bash_aliases/bash_aliases)" >&2
    exit 1
fi

((${#CMDS[@]})) || {
    echo "enterssh: no ssh aliases found in $ALIASES" >&2
    exit 1
}

# -m so Tab can mark servers; Enter on a single line behaves exactly as before.
mapfile -t SEL < <( { print_menu | sort; printf '%s\n' "$MANUAL"; } \
    | fzf -m --layout=reverse --height=40% --prompt='ssh> ' --info=inline \
        --bind='tab:toggle' --bind='btab:toggle' --marker='┃' --pointer='▸' --color='marker:green,pointer:white' \
        --bind='ctrl-u:preview-half-page-up' --bind='ctrl-d:preview-half-page-down' \
        --header='enter=ssh · tab=mark (2+ -> tmux panes) · esc=quit · ctrl-u/d=scroll' \
        --preview-window='right:45%:follow' --preview="$0 --_preview {}" )

((${#SEL[@]})) || exit 0

if ((${#SEL[@]} == 1)) && [ "${SEL[0]}" = "$MANUAL" ]; then
    manual_connect
fi

# A single pick -> plain ssh. Marked 2+ (or --pane) -> one tmux pane each.
if [ "$MODE" = "pane" ] || ((${#SEL[@]} > 1)); then
    run_panes "${SEL[@]}"
    exit $?
fi

name=${SEL[0]%%  *}
exec ${CMDS[$name]:-ssh}