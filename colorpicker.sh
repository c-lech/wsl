#!/usr/bin/env bash

usage() {
  cat <<'EOF'
colorpicker — Pick a Windows screen color, toast the result

Usage:
  colorpicker [OPTIONS]

Options:
  -h, --help      Show this help

Examples:
  colorpicker      # point & click -> toast: name · #hex · rgb(r,g,b) + swatch
  colorpicker -h   # this help

Notes:
  Signals PowerToys Color Picker; waits for the picked color on the clipboard.
  Toast duration: short (~5s).
  Requires: PowerToys running.
  Exit codes: 0 = picked, 1 = cancelled or PowerToys not running.
EOF
  exit 0
}

case "${1:-}" in -h|--help) usage ;; esac

res="$(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe \
  -NoProfile -STA -ExecutionPolicy Bypass \
  -File 'C:\data\shared\infra\windows_scripts\colorpicker.ps1' 2>&1)"
rc=$?

hex="$(printf '%s\n'   "$res"   | sed -n 's/^HEX=//p'    | head -n1)"
rgb="$(printf '%s\n'   "$res"   | sed -n 's/^RGB=//p'    | head -n1)"
value="$(printf '%s\n' "$res"   | sed -n 's/^PICKED=//p' | head -n1)"
[ -n "$hex" ] || hex="$value"
name="$(printf '%s\n' "$res"    | sed -n 's/^NAME=//p'  | head -n1)"
swatch="$(printf '%s\n' "$res"  | sed -n 's/^SWATCH=//p'| head -n1)"

if [ "$rc" -eq 0 ] && [ -n "$hex" ]; then
  if [ -n "$name" ]; then
    name="$(printf '%s' "$name" | awk '{ print toupper(substr($0,1,1)) substr($0,2) }')"
  else
    name="Picked"
  fi
  if [ -z "$rgb" ]; then
    rgb="$(printf '%s %s %s\n' "${hex:1:2}" "${hex:3:2}" "${hex:5:2}" |
      awk '{ printf "%d, %d, %d", strtonum("0x" $1), strtonum("0x" $2), strtonum("0x" $3) }')"
  fi
  [ -n "$rgb" ] || rgb="$hex"

  rows="$name|$hex|${rgb// /}"
  if [ -n "$swatch" ]; then
    "$HOME/wsl/notifywin.sh" --image "$swatch" --rows "$rows"
  else
    "$HOME/wsl/notifywin.sh" --rows "$rows"
  fi
  if [ -n "$swatch" ]; then
    rm -f "$(wslpath -u "$swatch" 2>/dev/null || true)"
  fi
  exit 0
fi

echo "cancelled (no color picked)" >&2
exit 1