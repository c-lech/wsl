#!/bin/bash
# checkbridge - verify WSL interop (running Windows .exe from Linux).
fail=0
[ -S "${WSL_INTEROP:-}" ] || { echo "[FAIL] WSL_INTEROP socket missing: ${WSL_INTEROP:-unset}"; fail=1; }
grep -qE '^enabled' /proc/sys/fs/binfmt_misc/WSLInterop || { echo "[FAIL] interop binfmt not enabled"; fail=1; }
command -v wsl.exe >/dev/null || { echo "[FAIL] wsl.exe not on PATH"; fail=1; }
timeout 5 cmd.exe /c ver >/dev/null 2>&1 || { echo "[FAIL] Windows round-trip failed (stale socket?)"; fail=1; }
[ "$fail" -eq 0 ] && { echo "bridge OK"; exit 0; }
exit 1