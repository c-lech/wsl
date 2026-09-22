#!/usr/bin/env bash
# save — Save Windows-clipboard image or text

set -uo pipefail

if [ "${1:-}" = "-h" ]; then
  cat <<'EOF'
save — Save Windows-clipboard image or text

Usage:
  save [OPTIONS]

Options:
  -h    Show this help

Examples:
  save           # image -> saveclip2img, text -> saveclip2txt, auto
  save -q 92     # image flag: JPEG quality 92
  save -p        # image flag: lossless PNG

Notes:
  Image on clipboard -> saveclip2img (image), text -> saveclip2txt (text).
  Flags are forwarded to the engine; exit codes are inherited from it.
  Depends on: wl-clipboard (wl-paste) + same deps as saveclip2img.sh/saveclip2txt.sh.
  Use 'saveclip2img -h' or 'saveclip2txt -h' for engine options.
  Exit codes: 0 = saved, 1 = nothing on clipboard or save failed, 2 = bad usage (engine).
EOF
  exit 0
fi

engine_for() { case "${1:-}" in        # clipboard kind -> saver script (empty if unknown)
  image) echo "$HOME/wsl/saveclip2img.sh" ;;
  text)  echo "$HOME/wsl/saveclip2txt.sh" ;;
esac; }

# Windows-first detection (bypasses the flaky WSLg mirror)
win="$(powershell.exe -NoProfile -STA -Command "Add-Type -AssemblyName System.Windows.Forms; if ([System.Windows.Forms.Clipboard]::ContainsImage()) {'image'} elseif ([System.Windows.Forms.Clipboard]::ContainsText()) {'text'} else {'none'}" 2>/dev/null | tr -d '\r' || true)"
eng="$(engine_for "$win")"
[ -n "$eng" ] && exec "$eng" "$@"

# WSLg bridge as last resort
types="$(wl-paste --list-types 2>/dev/null || true)"   # what does the clipboard offer?
for t in image/png image/bmp image/jpeg; do            # image beats text, png > bmp > jpeg
  grep -qx "$t" <<<"$types" && { eng="$(engine_for image)"; break; }
done
[ -n "${eng:-}" ] && exec "$eng" "$@"

grep -q "^text/" <<<"$types" && exec "$(engine_for text)" "$@"

echo "save: no image or text on clipboard - re-copy first" >&2
exit 1