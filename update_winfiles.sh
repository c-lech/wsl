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

# name|windows dir (relative to %USERPROFILE%)|windows file|repo file
specs=(
  "yasb|.config/yasb|config.yaml|yasb-config.yaml"
  "yasb|.config/yasb|styles.css|yasb-styles.css"
  "glazewm|.glzr/glazewm|config.yaml|glazewm-config.yaml"
  "vscode|AppData/Roaming/Code/User|settings.json|vscode-settings.json"
)

n_ok=0
n_skip=0
n_missing=0

group() {
  [ "$1" = "$last_group" ] && return 0
  printf '%s\n' "$1"
  last_group="$1"
}

pull() {
  local src="$1" repo="$2"

  if [ ! -f "$src" ]; then
    printf '  %s[skip]%s %s not found\n' "$C_SKIP" "$RESET" "$repo"
    n_missing=$(( n_missing + 1 ))
    return 0
  fi
  if cmp -s "$src" "$DEST/$repo"; then
    printf '  %s[skip]%s %s identical\n' "$C_SKIP" "$RESET" "$repo"
    n_skip=$(( n_skip + 1 ))
    return 0
  fi
  # drvfs hands over mode 744; the repo keeps configs non-executable at 644
  cp "$src" "$DEST/$repo"
  chmod 644 "$DEST/$repo"
  printf '  %s[ok]%s   %s\n' "$C_OK" "$RESET" "$repo"
  n_ok=$(( n_ok + 1 ))
}

last_group=""

for spec in "${specs[@]}"; do
  IFS='|' read -r name rel file repo <<< "$spec"
  group "$name"
  pull "$win_home/$rel/$file" "$repo"
done

# WT ships as an MSIX, so its folder carries the release channel - glob it
for wt_dir in "$win_home"/AppData/Local/Packages/Microsoft.WindowsTerminal*/LocalState; do
  [ -f "$wt_dir/settings.json" ] || continue
  group "wt"
  pull "$wt_dir/settings.json" "wt-settings.json"
  break
done

echo
printf '%s%d ok | %d skip | %d missing%s\n' "$C_DIM" "$n_ok" "$n_skip" "$n_missing" "$RESET"

if [ "$n_ok" -gt 0 ]; then
  if [ "$n_ok" -eq 1 ]; then
    echo "1 file updated. Run ./push.sh"
  else
    echo "$n_ok files updated. Run ./push.sh"
  fi
else
  echo "Nothing to do."
fi
