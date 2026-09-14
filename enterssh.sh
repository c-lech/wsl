#!/usr/bin/env bash
# enterssh - pick a server and ssh in, fuzzy style. Uses your ssh aliases.
#
#   enterssh             show menu, pick a server -> ssh
#   enterssh --list      just print the menu (see what it found)
#
# The menu is built from the ssh aliases in ~/.bash_aliases (the same file
# bash reads at shell start). Any `alias name="ssh ..."` line shows up
# automatically. The browser alias (zbx) is skipped, it's not ssh.
#
# Last line of the menu: "type an IP yourself" -> prompts for IP, then a
# user (Enter = root), and connects as user@ip while letting you keep your
# default host in the SSH config if you know one.
#
# Requires: fzf

set -uo pipefail

ALIASES="${HOME}/.bash_aliases"
[ -f "$ALIASES" ] || ALIASES="${HOME}/wsl/dotfiles/bash_aliases"

command -v fzf >/dev/null 2>&1 || {
    echo "enterssh: fzf is not installed (apt install fzf)" >&2
    exit 1
}

if [ ! -f "$ALIASES" ]; then
    echo "enterssh: no ssh aliases found (looked at ${HOME}/.bash_aliases)" >&2
    exit 1
fi

MANUAL="--- type an IP yourself ---"

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
    local name
    for name in "${!CMDS[@]}"; do
        printf '%s  %s\n' "$name" "${DISP[$name]}"
    done
}

if [ "${1:-}" = "--list" ]; then
    print_menu | sort
    printf '%s\n' "$MANUAL"
    exit 0
fi

if ((${#CMDS[@]} == 0)); then
    echo "enterssh: no ssh aliases found in $ALIASES" >&2
    exit 1
fi

SEL=$({ print_menu | sort; printf '%s\n' "$MANUAL"; } | fzf --layout=reverse --height=40% --prompt='ssh> ' --info=inline)

[ -z "$SEL" ] && exit 0

if [ "$SEL" = "$MANUAL" ]; then
    read -rp 'IP: ' IP
    [ -n "$IP" ] || exit 1
    read -rp 'User (Enter=root): ' USER
    USER=${USER:-root}
    exec ssh "${USER}@${IP}"
fi

name=${SEL%%  *}
exec ${CMDS[$name]:-ssh}