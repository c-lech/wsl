#!/bin/bash
# update_winfiles - Pull Windows app configs into dotfiles/windows/

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
win_home_win="$(wslpath -w "$win_home")"

n_ok=0
n_skip=0
n_missing=0
last_group=""

print_group() {
  local g="$1"
  case "$g" in
    wsl) printf 'Windows Subsystem for Linux\n';;
    yasb) printf 'YASB\n';;
    glazewm) printf 'GlazeWM\n';;
    vscode) printf 'Visual Studio Code\n';;
    wt) printf 'Windows Terminal\n';;
    *) printf '%s\n' "$g";;
  esac
}

# Windows-relative path for display, backslashes as Windows spells them.
# The WT package folder carries the release channel, so that one path is
# shortened - same substitution install.sh makes.
display_path() {
  local rel="${1#"$win_home"/}"
  case "$rel" in
    AppData/Local/Packages/Microsoft.WindowsTerminal*)
      printf 'AppData\\Local\\...\\LocalState\\settings.json\n'
      ;;
    AppData/Local/Microsoft/Windows\ Terminal/*)
      printf 'AppData\\Local\\Windows Terminal\\settings.json\n'
      ;;
    *)
      printf '%s\n' "${rel//\//\\}"
      ;;
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
  local rel="$1"
  local status="$2"
  local msg="$3"

  local W=45
  printf '  %s' "$rel"
  local pad=$(( W - ${#rel} ))
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
  local rel
  rel="$(display_path "$src")"

  if [ ! -f "$src" ]; then
    pad_and_print "$rel" "missing" "not found"
    return 0
  fi
  if cmp -s "$src" "$DEST/$repo_name"; then
    pad_and_print "$rel" "skip" "identical"
    return 0
  fi
  # drvfs hands over mode 744; the repo keeps configs non-executable at 644
  cp "$src" "$DEST/$repo_name"
  chmod 644 "$DEST/$repo_name"
  pad_and_print "$rel" "ok" "updated"
}

printf 'Updated from %s\\\n\n' "$win_home_win"

group_line "wsl"
pull "$win_home/.wslconfig" "wslconfig"

# WT ships as an MSIX, so its folder carries the release channel - glob it.
# Unpackaged builds (GitHub, Scoop, Chocolatey) keep settings.json outside
# Packages instead, so that path is tried too.
group_line "wt"
wt_target=''
for wt_dir in "$win_home"/AppData/Local/Packages/Microsoft.WindowsTerminal*/LocalState; do
  if [ -f "$wt_dir/settings.json" ]; then
    wt_target="$wt_dir/settings.json"
    break
  fi
done
if [ -z "$wt_target" ] && \
   [ -f "$win_home/AppData/Local/Microsoft/Windows Terminal/settings.json" ]; then
  wt_target="$win_home/AppData/Local/Microsoft/Windows Terminal/settings.json"
fi
# left unresolved, the glob still renders the shortened display path
if [ -z "$wt_target" ]; then
  wt_target="$win_home/AppData/Local/Packages/Microsoft.WindowsTerminal*/LocalState/settings.json"
fi
pull "$wt_target" "wt-settings.json"

group_line "glazewm"
pull "$win_home/.glzr/glazewm/config.yaml" "glazewm-config.yaml"

group_line "yasb"
pull "$win_home/.config/yasb/config.yaml" "yasb-config.yaml"
pull "$win_home/.config/yasb/styles.css" "yasb-styles.css"

group_line "vscode"
pull "$win_home/AppData/Roaming/Code/User/settings.json" "vscode-settings.json"

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
