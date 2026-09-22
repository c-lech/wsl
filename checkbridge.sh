#!/bin/bash
# checkbridge - verify WSL interop (running Windows .exe from Linux).

usage() {
  cat <<'EOF'
checkbridge — Verify WSL interop (running Windows .exe from Linux)

Usage:
  checkbridge [OPTIONS]

Options:
  -h    Show this help

Examples:
  checkbridge      # -> "bridge OK" or one or more [FAIL] lines

Notes:
  A FAIL means the WSLInterop binfmt entry vanished (WSL_INTEROP socket
  missing or binfmt_misc/WSLInterop disabled). Healing is manual on
  purpose — confirmed fix, as root:

    sudo -n sh -c 'echo ":WSLInterop:M::MZ::/init:P" > /proc/sys/fs/binfmt_misc/register'

  Lighter alternative (still pending verification):

    sudo -n systemctl restart systemd-binfmt.service

  After running either, re-run checkbridge — it should print "bridge OK".
  Exit codes: 0 = bridge OK, 1 = some check failed.
EOF
  exit 0
}

[ "${1:-}" = "-h" ] && usage

fail=0

if [ -S "${WSL_INTEROP:-}" ]; then
  echo "[ok]   WSL_INTEROP socket present"
else
  echo "[FAIL] WSL_INTEROP socket missing: ${WSL_INTEROP:-unset}"
  fail=1
fi

if grep -qE '^enabled' /proc/sys/fs/binfmt_misc/WSLInterop; then
  echo "[ok]   binfmt WSLInterop enabled"
else
  echo "[FAIL] interop binfmt not enabled"
  fail=1
fi

if command -v wsl.exe >/dev/null; then
  echo "[ok]   wsl.exe on PATH"
else
  echo "[FAIL] wsl.exe not on PATH"
  fail=1
fi

if timeout 5 cmd.exe /c ver >/dev/null 2>&1; then
  echo "[ok]   Windows round-trip (cmd /c ver)"
else
  echo "[FAIL] Windows round-trip failed (stale socket?)"
  fail=1
fi

echo

if [ "$fail" -eq 0 ]; then
  echo "bridge OK"
  exit 0
fi
echo "  Fix: sudo -n sh -c 'echo \":WSLInterop:M::MZ::/init:P\" > /proc/sys/fs/binfmt_misc/register'"
echo "  Then re-run checkbridge."
exit 1