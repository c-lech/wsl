#!/usr/bin/env bash
# notifywin — Pop a Windows notification from the terminal or any script

rc0=$?                                  # exit code of whatever ran just before us
set -uo pipefail

delay=0                                 # -d, --delay: wait before the toast
show=3                                  # -s, --show: balloon visible seconds

usage() {
  cat <<'EOF'
notifywin — Pop a Windows notification from the terminal or any script

Usage:
  notifywin [OPTIONS] COMMAND [ARGS...]   # run & time it, then notify
  notifywin [OPTIONS] [MESSAGE...]        # just notify now

Options:
  -d, --delay SECS    Wait SECS before the toast appears (default 0)
  -s, --show SECS     Seconds the balloon stays visible (default 3)
  -h, --help          Show this help

Examples:
  notifywin ./install.sh       # -> ./install.sh · done · 2m 14s
  notifywin tea is ready
  notifywin -d 3600 fix the box

Notes:
  Background toast · needs Windows.
  Exit codes: 0 shown · 1 no powershell · 2 bad usage (timed command returns its own rc).
EOF
  exit 0
}

fmt_elapsed() {                          # 45s | 2m 14s | 1h 02m
  local e=$1 h m s
  h=$((e / 3600)); m=$(((e % 3600) / 60)); s=$((e % 60))
  if   [ "$h" -gt 0 ]; then printf '%dh %02dm' "$h" "$m"
  elif [ "$m" -gt 0 ]; then printf '%dm %02ds' "$m" "$s"
  else                        printf '%ds'     "$s"
  fi
}

notify_toast() {                         # $1 message, $2 info|error
  local msg="$1" icon="$2" esc icon_expr dur logo_win reg_line tmp
  command -v powershell.exe >/dev/null 2>&1 || {
    echo "notifywin: powershell.exe not found - needs Windows" >&2; return 1; }
  msg="${msg//$'\n'/ }"                  # toasts are one line
  msg="${msg:0:120}"
  esc="${msg//\'/\'\'}"                  # escape for a PS single-quoted string
  if [ "$icon" = error ]; then
    icon_expr='[System.Drawing.SystemIcons]::Error'
  else
    icon_expr='[System.Drawing.SystemIcons]::Information'
  fi
  reg_line=""
  if [ -f "$HOME/shared/infra/notifywin/logo.ico" ]; then   # registry icon -> small, left of the name
    logo_win="$(wslpath -w "$HOME/shared/infra/notifywin/logo.ico")"
    reg_line="New-ItemProperty \$key -Name 'IconUri' -Value '$logo_win' -Force | Out-Null"
  fi
  [ "$show" -gt 3 ] && dur=long || dur=short
  tmp="${TMPDIR:-/tmp}/notifywin_$$.ps1"
  {
    printf '\xEF\xBB\xBF'                 # UTF-8 BOM so powershell.exe reads the file as UTF-8, not ANSI
    printf '%s\n' "\$ErrorActionPreference = 'Stop'"
    printf '%s\n' "\$msg = '$esc'"
    printf '%s\n' "\$key = 'HKCU:\\Software\\Classes\\AppUserModelId\\notifywin3'"
    printf '%s\n' "if (-not (Test-Path \$key)) { New-Item \$key -Force | Out-Null }"
    printf '%s\n' "New-ItemProperty \$key -Name DisplayName -Value 'notifywin' -Force | Out-Null"
    printf '%s\n' "$reg_line"
    cat <<'PS1'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Aumid {
  [DllImport("shell32.dll")]
  public static extern int SetCurrentProcessExplicitAppUserModelID(string AppID);
}
'@
[Aumid]::SetCurrentProcessExplicitAppUserModelID('notifywin3') | Out-Null

$null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType=WindowsRuntime]
$null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime]
$null = [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType=WindowsRuntime]

try {
  $esc = $msg.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
  $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
  $xml.LoadXml("<toast duration='__DUR__'><visual><binding template='ToastGeneric'><text>$esc</text></binding></visual></toast>")
  $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
  [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('notifywin3').Show($toast)
  Write-Output 'TRY_OK'
} catch {
  try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $n = New-Object System.Windows.Forms.NotifyIcon
    $n.Icon = __ICON__
    $n.Visible = $true
    $n.BalloonTipTitle = 'notifywin'
    $n.BalloonTipText = $msg
    $n.ShowBalloonTip(3000)
    $dl = (Get-Date).AddSeconds(6)
    while ((Get-Date) -lt $dl) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 100 }
    $n.Dispose()
    Write-Output 'CATCH_FB'
  } catch {
    Write-Output 'CATCH_ERR'
  }
}
PS1
  } > "$tmp"
  perl -pi -e "s/__DUR__/$dur/g; s/__ICON__/${icon_expr}/g" "$tmp"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$tmp" >"$tmp.log" 2>&1 &
  ( sleep 30; rm -f "$tmp" "$tmp.log" ) >/dev/null 2>&1 &
}

while [ $# -gt 0 ]; do
  case "$1" in
    -d|--delay)
      shift
      [ $# -gt 0 ] && [[ "$1" =~ ^[0-9]+$ ]] || { echo "notifywin: --delay needs a number of seconds" >&2; exit 2; }
      delay=$1; shift ;;
    --delay=*)
      delay=${1#*=}
      [[ "$delay" =~ ^[0-9]+$ ]] || { echo "notifywin: --delay needs a number of seconds" >&2; exit 2; }
      shift ;;
    -s|--show)
      shift
      [ $# -gt 0 ] && [[ "$1" =~ ^[0-9]+$ ]] || { echo "notifywin: --show needs a number of seconds" >&2; exit 2; }
      show=$1; shift ;;
    --show=*)
      show=${1#*=}
      [[ "$show" =~ ^[0-9]+$ ]] || { echo "notifywin: --show needs a number of seconds" >&2; exit 2; }
      shift ;;
    -h|--help) usage ;;
    --) shift; break ;;
    -*) echo "notifywin: unknown option '$1' (see notifywin -h)" >&2; exit 2 ;;
    *) break ;;
  esac
done

# Run & time: first arg is a path (has / or exists) -> wrap it and measure it.
if [ $# -gt 0 ] && { [[ "$1" == */* ]] || [ -e "$1" ]; }; then
  base="$(basename "$1")"
  t0="$(date +%s)"
  "$@"
  rc=$?
  t1="$(date +%s)"
  dur="$(fmt_elapsed $((t1 - t0)))"
  if [ "$rc" -eq 0 ]; then
    notified="info";  msg="✓ $base · done · $dur"
  else
    notified="error"; msg="✗ $base · failed rc $rc · $dur"
  fi
  final=$rc
else
  if [ $# -gt 0 ]; then                     # message from args
    msg="$*"
  elif ! [ -t 0 ]; then                     # message from a pipe's first line
    IFS= read -r line || true
    msg="${line%$'\r'}"
    [ -n "$msg" ] || msg="done"
  else                                      # nothing said
    msg="done"
  fi
  if [ "$rc0" -ne 0 ]; then
    notified="error"
    [ "$msg" = done ] && msg="failed (rc $rc0)"
  else
    notified="info"
  fi
  final=0
fi

[ "$delay" -gt 0 ] && sleep "$delay"
notify_toast "$msg" "$notified" || exit 1
exit "$final"