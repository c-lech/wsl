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
  savetmux      # -> ~/shared/saved/260921_143022_tmux/{1_1.txt,1_2.txt,2_1.txt}

Notes:
  Grabs the full scroll-back of every pane; 1 pane = 1 file, N panes = N files,
  all inside one timestamped folder. Naming is time-ordered, so ls is chronological.
  Requires: running inside tmux.
  Exit codes: 0 = saved, 1 = not in tmux or save failed.
EOF
  exit 0
}

say_saved() {                                # clickable 'saved:' line; plain when piped
  if [ -t 1 ]; then
    local uri
    uri="file:///$(wslpath -m "$1")"         # Windows path -> Ctrl+click opens
    printf '\e]8;;%s\e\\saved: %s\e]8;;\e\\\n'  "$uri" "$(basename "$1")"
  else
    echo "saved: $1"
  fi
}

say_folder() {                               # clickable folder link; plain when piped
  if [ -t 1 ]; then
    local dir_win
    dir_win="$(wslpath -m "$1")"
    printf '\e]8;;file:///%s/\e\\folder: %s\e]8;;\e\\\n'  "$dir_win" "$dir_win"
  else
    echo "folder: $1"
  fi
}

if [ "${1:-}" = "-h" ]; then usage; fi

if [ -z "${TMUX:-}" ]; then
    echo "savetmux: run me inside tmux" >&2
    exit 1
fi

dir="$HOME/shared/saved"
stamp="$(date +%y%m%d_%H%M%S)"
sid="$(tmux display-message -p '#{session_name}')"     # capture target only, not in the path

run="$dir/${stamp}_tmux"
mkdir -p "$run" || { echo "savetmux: can't create $run" >&2; exit 1; }

mapfile -t panes < <(tmux list-panes -s -t "$sid" -F '#{window_index}.#{pane_index}')

[ "${#panes[@]}" -gt 0 ] || { echo "savetmux: no panes found" >&2; exit 1; }

for p in "${panes[@]}"; do
    win="${p%%.*}"
    idx="${p#*.}"
    out="$run/${win}_${idx}.txt"
    if tmux capture-pane -t "${sid}:${win}.${idx}" -p -S - > "$out"; then
        say_saved "$out"
    else
        echo "savetmux: pane ${win}.${idx} capture failed" >&2
        exit 1
    fi
done
say_folder "$run"

notify_saved() {                             # toast: live tmux-window shot + folder Open; never fails the save
  local shot shot_win folder_win rows win_temp
  folder_win="$(wslpath -w "$run" 2>/dev/null || true)"
  rows="Saved tmux|${#panes[@]} panes|$(basename "$run")"
  shot=""
  win_temp="$(wslpath "$(powershell.exe -NoProfile -Command '$env:TEMP' 2>/dev/null | tr -d '\r' || true)" 2>/dev/null || true)"
  if [ -n "$win_temp" ]; then
    shot="$win_temp/tmx_view_$$.png"
    rm -f "$shot"
    shot_win="$(wslpath -w "$shot" 2>/dev/null || true)"
    if [ -n "$shot_win" ]; then
      ( cd "$HOME/shared/infra/windows_scripts" && cmd.exe /c "saveshot.bat winpng $shot_win" ) >/dev/null 2>&1
      [ -s "$shot" ] || { echo "savetmux: window preview not captured - foreground window unavailable" >&2; shot=""; }
    fi
  fi
  if [ -n "$shot" ] && [ -n "$folder_win" ]; then
    shot_win="$(wslpath -w "$shot" 2>/dev/null || true)"
    [ -n "$shot_win" ] && "$HOME/wsl/notifywin.sh" --image "$shot_win" --open "$folder_win" --rows "$rows" >/dev/null 2>&1 || true
  elif [ -n "$folder_win" ]; then
    "$HOME/wsl/notifywin.sh" --open "$folder_win" --rows "$rows" >/dev/null 2>&1 || true
  fi
}
notify_saved