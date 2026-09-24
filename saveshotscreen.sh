#!/usr/bin/env bash
# saveshotscreen — Save the Windows screen as image

set -uo pipefail

if [ "${1:-}" = "-h" ]; then
  cat <<'EOF'
saveshotscreen — Save the Windows screen as image

Usage:
  saveshotscreen [DELAY]

Options:
  -h       Show this help
  DELAY    optional seconds to wait before the capture (default 0)

Examples:
  saveshotscreen      # instant
  saveshotscreen 5    # wait 5s (time to focus the target), then capture

Notes:
  Copies the screen to the Windows clipboard, then saveclip2img saves it
  to ~/shared/saved/.
  Requires: Windows + WSLg clipboard bridge.
  Exit codes: 0 = saved, 1 = nothing on clipboard or save failed.
EOF
  exit 0
fi

delay=0
if (($#)); then
  [[ "$1" =~ ^[0-9]+$ ]] || { echo "saveshotscreen: bad delay '$1' (a number of seconds, 0 = instant)" >&2; exit 2; }
  delay=$1
fi

cd "$HOME/shared/infra/bat"
cmd.exe /c saveshot.bat full "$delay"
