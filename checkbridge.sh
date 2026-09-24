#!/bin/bash
# checkbridge - verify WSL interop (running Windows .exe from Linux)
# Auto-repairs the socket case; the binfmt_misc case needs root (hint printed).

set -uo pipefail

C_OK=''
C_FAIL=''
C_SKIP=''
RESET=''
if [ -t 1 ]; then
  C_OK=$'\033[32m'
  C_FAIL=$'\033[31m'
  C_SKIP=$'\033[33m'
  RESET=$'\033[0m'
fi

usage() {
  cat <<'EOF'
checkbridge — Verify WSL interop (running Windows .exe from Linux)

Usage:  checkbridge [OPTIONS]

Options:
  -h    Show this help

Examples:
  checkbridge      # -> "bridge OK" or one or more [FAIL] lines

Notes:
  A FAIL means the WSLInterop socket is missing/stale or the binfmt_misc
  WSLInterop entry is disabled. The script self-repairs the socket case
  (probes /run/WSL/*_interop and re-wires to a working socket). If no
  socket survives, the binfmt entry must be registered as root:

    sudo -n sh -c 'echo ":WSLInterop:M::MZ::/init:P" > /proc/sys/fs/binfmt_misc/register'

  (lighter, still unverified: sudo -n systemctl restart systemd-binfmt.service)
  Re-run after either fix - output should end with "bridge OK".

Exit: 0 = bridge OK (incl. auto-repaired), 1 = repair needed/failed
EOF
  exit 0
}

[ "${1:-}" = "-h" ] && usage

fail=0

if [ -S "${WSL_INTEROP:-}" ]; then
  echo "  ${C_OK}[ok]${RESET}   WSL_INTEROP socket present"
else
  echo "  ${C_FAIL}[FAIL]${RESET} WSL_INTEROP socket missing: ${WSL_INTEROP:-unset}"
  fail=1
fi

if grep -qE '^enabled' /proc/sys/fs/binfmt_misc/WSLInterop; then
  echo "  ${C_OK}[ok]${RESET}   binfmt WSLInterop enabled"
else
  echo "  ${C_FAIL}[FAIL]${RESET} interop binfmt not enabled"
  fail=1
fi

if command -v wsl.exe >/dev/null; then
  echo "  ${C_OK}[ok]${RESET}   wsl.exe on PATH"
else
  echo "  ${C_FAIL}[FAIL]${RESET} wsl.exe not on PATH"
  fail=1
fi

if timeout 5 cmd.exe /c ver >/dev/null 2>&1; then
  echo "  ${C_OK}[ok]${RESET}   Windows round-trip (cmd /c ver)"
else
  echo "  ${C_FAIL}[FAIL]${RESET} Windows round-trip failed (stale socket?)"
  fail=1
fi

echo

if [ "$fail" -eq 0 ]; then
  echo "  ${C_OK}bridge OK${RESET}"
  exit 0
fi

# Auto-repair: probe the interop sockets newest-first, re-wire to one that works.
picked=""
for s in $(ls -t /run/WSL/*_interop 2>/dev/null); do
  if WSL_INTEROP="$s" timeout 5 cmd.exe /c ver >/dev/null 2>&1; then
    picked="$s"
    break
  fi
done

if [ -n "$picked" ]; then
  echo "  ${C_OK}bridge OK${RESET} (${C_SKIP}repaired: WSL_INTEROP=$picked${RESET})"
  echo "  this shell still has the old value: paste this now:"
  echo "  export WSL_INTEROP=$picked"
  echo "  or open a NEW terminal - it will be OK by itself"
  exit 0
fi

echo "  ${C_FAIL}bridge NOT-OK${RESET} - repair needs root:"
echo "  sudo -n sh -c 'echo \":WSLInterop:M::MZ::/init:P\" > /proc/sys/fs/binfmt_misc/register'"
echo "  re-run after fixing"
exit 1