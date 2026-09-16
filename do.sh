#!/bin/bash
# do - fuzzy launcher over your toolbox: pick a command, Enter runs it
#
# Sources (live, every launch - no cache):
#   - aliases from ~/shared/infra/bash_aliases/bash_aliases (all except SSH shortcuts)
#   - every ~/wsl/**/*.sh (recursive, any depth), grouped by folder
# Rules:
#   - alias wins if it points at a script (no duplicate entries)
#   - install.sh and do.sh are never listed
# Usage:
#   do                pick a command and run it (in your current shell)
#   do.sh --list      print all entries (name<TAB>command)
#   do.sh --_preview  internal: fzf preview helper
#
# Runs via:   alias do='eval "$($HOME/wsl/do.sh --sel)"'
# eval means env/history/functions survive - matching how enterssh runs ssh.
set -uo pipefail
shopt -s globstar nullglob

BASE="$HOME/wsl"
ALIASES=""
for c in "$HOME/shared/infra/bash_aliases/bash_aliases" \
         "/mnt/c/data/shared/infra/bash_aliases/bash_aliases"; do
    [ -f "$c" ] && { ALIASES="$c"; break; }
done

C_RESET=$'\033[0m'
C_DIM=$'\033[2m'
C_MAG=$'\033[35m'

declare -a E_NAME=() E_TYPE=() E_DESC=() E_CMD=()

script_meta() {
    local f=$1 l d
    while IFS= read -r l; do
        [[ "$l" == '#!'* ]] && continue
        [[ "$l" == '#'* ]] || break
        d="${l#\# }"
        [[ "$d" =~ ^[A-Za-z0-9] ]] && { printf '%s' "$d"; return; }
    done < "$f"
}

header_block() {
    local f=$1 l had=false n=0
    while IFS= read -r l; do
        [[ "$l" == '#!'* ]] && continue
        if [[ "$l" == '#'* ]]; then
            printf '%s\n' "${l#\# }"
            had=true
            ((++n >= 8)) && return
        elif [[ -z "$l" ]]; then
            [[ "$had" == true ]] && return
            continue
        else
            return
        fi
    done < "$f"
}

build() {
    local -a lines=() AP=()
    local i l prev next sec="" pd="" v path p f rel skip name
    E_NAME=(); E_TYPE=(); E_DESC=(); E_CMD=()

    if [[ -f $ALIASES ]]; then
        mapfile -t lines < "$ALIASES"
        for ((i = 0; i < ${#lines[@]}; i++)); do
            l=${lines[$i]%$'\r'}
            prev="${lines[$((i - 1))]:-}"; prev=${prev%$'\r'}
            next="${lines[$((i + 1))]:-}"; next=${next%$'\r'}
            [[ "$l" =~ ^#[[:space:]-]+$ ]] && continue
            if [[ "$l" == '#'* ]]; then
                if [[ "$prev" =~ ^#[[:space:]-]+$ && "$next" =~ ^#[[:space:]-]+$ ]]; then
                    sec="${l#\# }"; pd=""
                else
                    pd="${l#\# }"
                fi
                continue
            fi
            [[ "$l" =~ ^alias[[:space:]]+([A-Za-z0-9_.-]+)= ]] || continue
            name=${BASH_REMATCH[1]}
            [[ "$name" == "do" ]] && continue
            [[ "$sec" == "SSH shortcuts" ]] && continue
            v="${l#alias ${name}=}"
            if [[ "$v" == \'* ]]; then
                v="${v#\'}"; v="${v%\'}"
            elif [[ "$v" == \"* ]]; then
                v="${v#\"}"; v="${v%\"}"
            fi
            path=""
            if [[ "$v" =~ (~/wsl|\$HOME/wsl)/([A-Za-z0-9_./-]+\.sh) ]]; then
                path=${BASH_REMATCH[2]}
            fi
            E_NAME+=("$name"); E_TYPE+=(alias); E_DESC+=("$pd"); E_CMD+=("$v")
            [[ -n "$path" ]] && AP+=("$path")
            pd=""
        done
    fi

    for f in "$BASE"/**/*.sh; do
        rel=${f#"$BASE"/}
        [[ "$rel" == "do.sh" || "$rel" == "install.sh" ]] && continue
        skip=false
        for p in "${AP[@]}"; do
            [[ "$p" == "$rel" ]] && skip=true
        done
        [[ "$skip" == true ]] && continue
        E_NAME+=("$rel"); E_TYPE+=(script); E_DESC+=("$(script_meta "$f")")
        E_CMD+=("bash \"$HOME/wsl/$rel\"")
    done
}

entry_index() {
    local name=$1 i
    for ((i = 0; i < ${#E_NAME[@]}; i++)); do
        [[ "${E_NAME[$i]}" == "$name" ]] && { printf '%s\n' "$i"; return 0; }
    done
    return 1
}

preview() {
    local name=$1 idx
    idx=$(entry_index "$name") || { printf '? %s\n' "$name"; return 0; }
    if [[ "${E_TYPE[$idx]}" == "alias" ]]; then
        printf '%s%s%s\n' "$C_MAG" "alias ${E_NAME[$idx]}" "$C_RESET"
        printf '%sruns: %s\n' "$C_DIM" "${E_CMD[$idx]}"
        if [[ -n "${E_DESC[$idx]}" ]]; then
            printf '%s%s%s\n' "$C_DIM" "${E_DESC[$idx]}" "$C_RESET"
        else
            printf '%s(no description)%s\n' "$C_DIM" "$C_RESET"
        fi
    else
        printf '%sruns: %s\n' "$C_DIM" "${E_CMD[$idx]}"
        [[ -n "${E_DESC[$idx]}" ]] && printf '%s%s%s\n' "$C_DIM" "${E_DESC[$idx]}" "$C_RESET"
        header_block "$HOME/wsl/${E_NAME[$idx]}"
    fi
}

if [[ "${1:-}" == "--_preview" ]]; then
    build
    preview "${2:-}"
    exit 0
fi

if [[ "${1:-}" == "--list" ]]; then
    build
    for ((i = 0; i < ${#E_NAME[@]}; i++)); do
        printf '%s\t%s\n' "${E_NAME[$i]}" "${E_CMD[$i]}"
    done
    exit 0
fi

build
if ((${#E_NAME[@]} == 0)); then
    echo "do: no commands found (${ALIASES} + ~/wsl scripts)" >&2
    exit 0
fi

mapfile -t SEL < <({
    for ((i = 0; i < ${#E_NAME[@]}; i++)); do
        printf '%s  %s\n' "${E_NAME[$i]}" "${E_DESC[$i]}"
    done
} | fzf --layout=reverse --height=40% --prompt='do> ' --info=inline \
    --marker='┃' --pointer='▸' --color='marker:green,pointer:white' \
    --preview-window='right:45%' \
    --header='enter=run · esc=quit' \
    --preview="$0 --_preview {}")

((${#SEL[@]})) || exit 0
name=${SEL[0]%%  *}
idx=$(entry_index "$name") || exit 0
printf '%s\n' "${E_CMD[$idx]}"