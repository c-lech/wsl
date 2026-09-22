#!/usr/bin/env bash
# saveshotwin — Save the active Windows window as image

set -uo pipefail

if [ "${1:-}" = "-h" ]; then
  cat <<'EOF'
saveshotwin — Save the active Windows window as image

Usage:
  saveshotwin [OPTIONS]

Options:
  -h    Show this help

Examples:
  saveshotwin    # -> ~/shared/saved/260921_143022_image.png

Notes:
  Powershell Alt+PrtSc copies the active window to the Windows clipboard,
  then saveclip2img saves it to ~/shared/saved/.
  Requires: Windows + WSLg clipboard bridge.
  Exit codes: inherited from saveclip2img (0 = saved, 1 = failed).
EOF
  exit 0
fi

cd "$HOME/shared/infra/bat"
cmd.exe /c saveshotwin.bat
