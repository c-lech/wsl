#!/usr/bin/env bash
# notifywin — Pop a Windows notification from the terminal or any script

rc0=$?                                  # exit code of whatever ran just before us
set -uo pipefail

delay=0                                 # -d, --delay: wait before the toast
show=3                                  # -s, --show: balloon visible seconds
image=""                                # --image FILE: square chip shown top-left
open=""                                 # --open FILE: 'Open' action button
rows=""                                 # --rows "A|B|C": one toast line per row, first bold

usage() {
  cat <<'EOF'
notifywin — Pop a Windows notification from the terminal or any script

Usage:
  notifywin [OPTIONS] COMMAND [ARGS...]   # run & time it, then notify
  notifywin [OPTIONS] [MESSAGE...]        # just notify now

Options:
  -d, --delay SECS    Wait SECS before the toast appears (default 0)
  -s, --show SECS     Visibility: 1-3 = short (~5s) · 4+ = long (~25s).
                      Default 3 (short).
  -i, --image FILE    Show FILE as a small square image in the toast
                      (any Windows path; e.g. a color swatch PNG)
  -o, --open FILE     Add an 'Open' action button that opens FILE
                      with its default Windows app when clicked
  -r, --rows "A|B|C"  One toast line per pipe-separated row: first line bold,
                      rest plain. Default: the message is a single line.
  -h, --help          Show this help

Examples:
  notifywin ./install.sh       # -> ./install.sh · done · 2m 14s
  notifywin tea is ready
  notifywin -d 3600 fix the box
  notifywin -s 5 tea is ready  # -> long toast (~25s)
  notifywin --rows "Black|#1E1E1E|30, 30, 30" --image C:\\tmp\\swatch.png

Notes:
  Background toast · needs Windows.
  Toast duration: short ~5s · long ~25s on Windows 11.
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

to_uri() {                               # windows path -> file:/// URI (XML-safe)
  local u="$1"
  u="${u//\\//}"
  case "$u" in
    file://*|http://*|https://*) ;;
    [A-Za-z]:/*) u="file:///$u" ;;
    /*) u="file://$u" ;;
  esac
  u="${u// /%20}"
  u="${u//&/&amp;}"
  u="${u//</&lt;}"
  u="${u//>/&gt;}"
  printf '%s' "$u"
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
  if [ -f "$HOME/shared/infra/notifywin_ico/notifywin.ico" ]; then   # registry icon -> small, left of the name
    logo_win="$(wslpath -w "$HOME/shared/infra/notifywin_ico/notifywin.ico")"
    reg_line="New-ItemProperty \$key -Name 'IconUri' -Value '$logo_win' -Force | Out-Null"
  fi
  img_xml=""                                  # optional square image chip (top-left)
  if [ -n "$image" ]; then
    img_xml="<image placement='appLogoOverride' id='1' src='$(to_uri "$image")'/>"
  fi
  act_xml=""                                  # optional 'Open' action button
  if [ -n "$open" ]; then
    act_xml="<actions><action content='Open' activationType='protocol' arguments='$(to_uri "$open")'/></actions>"
  fi
  [ "$show" -gt 3 ] && dur=long || dur=short
  tmp="${TMPDIR:-/tmp}/notifywin_$$.ps1"
  tmp_win="$(wslpath -w "$tmp" 2>/dev/null || printf '%s' "$tmp")"
  {
    printf '\xEF\xBB\xBF'                 # UTF-8 BOM so powershell.exe reads the file as UTF-8, not ANSI
    printf '%s\n' "\$ErrorActionPreference = 'Stop'"
    printf '%s\n' "\$msg = '$esc'"
    if [ -n "$rows" ]; then
      printf '%s\n' "\$rows = @("
      IFS='|' read -r -a _rowparts <<< "$rows"
      _n=${#_rowparts[@]}
      _i=0
      for _p in "${_rowparts[@]}"; do
        _p="${_p//$'\n'/ }"
        _pesc="${_p//\'/\'\'}"
        _i=$((_i + 1))
        if [ "$_i" -lt "$_n" ]; then
          printf '%s\n' "  '$_pesc',"
        else
          printf '%s\n' "  '$_pesc'"
        fi
      done
      printf '%s\n' ")"
    fi
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

if ($rows) { $msg = ($rows -join ' | ') }   # balloon fallback text

try {
  $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
  if ($rows) {
    $texts = @()
    foreach ($r in $rows) {
      $e = $r.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
      $texts += "<text>$e</text>"
    }
    $xml.LoadXml("<toast duration='__DUR__'><visual><binding template='ToastGeneric'>__IMG____ROWS__</binding></visual>__ACT__</toast>".Replace('__ROWS__', ($texts -join '')))
  } else {
    $esc = $msg.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
    $xml.LoadXml("<toast duration='__DUR__'><visual><binding template='ToastGeneric'><text>$esc</text>__IMG__</binding></visual>__ACT__</toast>")
  }
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
  perl -pi -e "s/__DUR__/$dur/g; s/__ICON__/${icon_expr}/g; s~__IMG__~${img_xml}~g; s~__ACT__~${act_xml}~g" "$tmp"
  res="$(timeout 20 powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$tmp_win" </dev/null 2>&1)"
  case "$res" in
    *TRY_OK*|*CATCH_FB*) rm -f "$tmp" ;;
    *) echo "notifywin: toast failed -> ${res:-<no output>}" >&2
       echo "notifywin: kept $tmp for inspection" >&2 ;;
  esac
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
    -i|--image)
      shift
      [ $# -gt 0 ] && [ -n "$1" ] || { echo "notifywin: --image needs a FILE path" >&2; exit 2; }
      image="$1"; shift ;;
    --image=*)
      image=${1#*=}
      [ -n "$image" ] || { echo "notifywin: --image needs a FILE path" >&2; exit 2; }
      shift ;;
    -o|--open)
      shift
      [ $# -gt 0 ] && [ -n "$1" ] || { echo "notifywin: --open needs a FILE path" >&2; exit 2; }
      open="$1"; shift ;;
    --open=*)
      open=${1#*=}
      [ -n "$open" ] || { echo "notifywin: --open needs a FILE path" >&2; exit 2; }
      shift ;;
    -r|--rows)
      shift
      [ $# -gt 0 ] && [ -n "$1" ] || { echo "notifywin: --rows needs ROW1|ROW2|..." >&2; exit 2; }
      rows="$1"; shift ;;
    --rows=*)
      rows=${1#*=}
      [ -n "$rows" ] || { echo "notifywin: --rows needs ROW1|ROW2|..." >&2; exit 2; }
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