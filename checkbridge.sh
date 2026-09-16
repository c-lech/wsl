#!/bin/bash
# checkbridge - verify WSL interop (running Windows .exe from Linux).
#
# If you see "[FAIL] interop binfmt not enabled" or "Windows round-trip failed",
# the WSLInterop binfmt entry went missing and Windows .exe files can't start.
# Re-register it with root. This command is confirmed to work:
#
#   sudo -n sh -c 'echo ":WSLInterop:M::MZ::/init:P" > /proc/sys/fs/binfmt_misc/register'
#
# A lighter alternative - re-runs WSL's own registration through systemd-binfmt.
# Still pending verification, test it next time this happens:
#
#   sudo -n systemctl restart systemd-binfmt.service
#
# Healing is manual on purpose; after running either, re-run this script and it
# should report "bridge OK".
fail=0
[ -S "${WSL_INTEROP:-}" ] || { echo "[FAIL] WSL_INTEROP socket missing: ${WSL_INTEROP:-unset}"; fail=1; }
grep -qE '^enabled' /proc/sys/fs/binfmt_misc/WSLInterop || { echo "[FAIL] interop binfmt not enabled"; fail=1; }
command -v wsl.exe >/dev/null || { echo "[FAIL] wsl.exe not on PATH"; fail=1; }
timeout 5 cmd.exe /c ver >/dev/null 2>&1 || { echo "[FAIL] Windows round-trip failed (stale socket?)"; fail=1; }
[ "$fail" -eq 0 ] && { echo "bridge OK"; exit 0; }
exit 1