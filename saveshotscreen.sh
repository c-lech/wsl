#!/usr/bin/env bash
# saveshotscreen — Save the Windows screen as image

set -uo pipefail

if [ "${1:-}" = "-h" ]; then
  cat <<'EOF'
saveshotscreen — Save the Windows screen as image

Usage:
  saveshotscreen [OPTIONS]

Options:
  -h    Show this help

Examples:
  saveshotscreen    # -> ~/shared/saved/260921_143022_image.png

Notes:
  Powershell CopyFromScreen copies the screen to the Windows clipboard,
  then saveclip2img saves it to ~/shared/saved/.
  Requires: Windows + WSLg clipboard bridge.
  Exit codes: inherited from saveclip2img (0 = saved, 1 = failed).
EOF
  exit 0
fi

cd "$HOME/shared/infra/bat"
cmd.exe /c saveshotscreen.bat
