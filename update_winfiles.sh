#!/bin/bash

set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$BASE/dotfiles/windows"

C_OK=''
C_SKIP=''
C_DIM=''
RESET=''
if [ -t 1 ]; then
  C_OK=$'\033[32m'
  C_SKIP=$'\033[33m'
  C_DIM=$'\033[2m'
  RESET=$'\033[0m'
fi

if ! command -v cmd.exe >/dev/null 2>&1 || ! command -v wslpath >/dev/null 2>&1; then
  echo "Not on WSL - nothing to pull from Windows." >&2
  exit 1
fi

win_home="$(wslpath -u "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")"

n_ok=0
n_skip=0
n_missing=0
last_group=""

print_group() {
  local g="$1"
  case "$g" in
    yasb) printf 'YASB\n';;
    glazewm) printf 'GlazeWM\n';;
    vscode) printf 'Visual Studio Code\n';;
    wt) printf 'Windows Terminal\n';;
    *) printf '%s\n' "$g";;
  esac
}

group_line() {
  local g="$1"
  if [ "$g" = "$last_group" ]; then
    return 0
  fi
  if [ -n "$last_group" ]; then
    echo
  fi
  print_group "$g"
  last_group="$g"
}

pad_and_print() {
  local repo_name="$1"
  local status="$2"
  local msg="$3"

  local W=45
  printf '  %s' "$repo_name"
  local pad=$(( W - ${#repo_name} ))
  for (( j=0; j<pad; j++ )); do
    printf '.'
  done

  case "$status" in
    ok)
      printf "  %s[ok]%s   %s\n" "$C_OK" "$RESET" "$msg"
      n_ok=$(( n_ok + 1 ))
      ;;
    skip)
      printf "  %s[skip]%s %s\n" "$C_SKIP" "$RESET" "$msg"
      n_skip=$(( n_skip + 1 ))
      ;;
    missing)
      printf "  %s[skip]%s %s\n" "$C_SKIP" "$RESET" "$msg"
      n_missing=$(( n_missing + 1 ))
      ;;
  esac
}

pull() {
  local src="$1" repo_name="$2"

  if [ ! -f "$src" ]; then
    pad_and_print "$repo_name" "missing" "not found"
    return 0
  fi
  if cmp -s "$src" "$DEST/$repo_name"; then
    pad_and_print "$repo_name" "skip" "identical"
    return 0
  fi
  # drvfs hands over mode 744; the repo keeps configs non-executable at 644
  cp "$src" "$DEST/$repo_name"
  chmod 644 "$DEST/$repo_name"
  pad_and_print "$repo_name" "ok" "updated"
}

group_line "yasb"
pull "$win_home/.config/yasb/config.yaml" "config.yaml"
pull "$win_home/.config/yasb/styles.css" "styles.css"

group_line "glazewm"
pull "$win_home/.glzr/glazewm/config.yaml" "glazewm-config.yaml"

group_line "vscode"
pull "$win_home/AppData/Roaming/Code/User/settings.json" "vscode-settings.json"

# WT ships as an MSIX, so its folder carries the release channel - glob it
for wt_dir in "$win_home"/AppData/Local/Packages/Microsoft.WindowsTerminal*/LocalState; do
  [ -f "$wt_dir/settings.json" ] || continue
  group_line "wt"
  pull "$wt_dir/settings.json" "wt-settings.json"
  break
done

echo
echo
printf '%s%d ok | %d skip | %d missing%s\n' "$C_DIM" "$n_ok" "$n_skip" "$n_missing" "$RESET"
echo

if [ "$n_ok" -gt 0 ]; then
  if [ "$n_ok" -eq 1 ]; then
    echo "1 file updated. Run ./push.sh"
  else
    echo "$n_ok files updated. Run ./push.sh"
  fi
else
  echo "Nothing to do."
fi
