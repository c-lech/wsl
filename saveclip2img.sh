#!/usr/bin/env bash
# saveclip2img — Save Windows-clipboard image

set -uo pipefail

q=100      # JPEG quality 0-100; 100 = near-lossless master, 92 = tiny but eye-identical
png=0      # 1 = PNG output (lossless); 0 = JPEG
out=""     # custom destination; empty = timestamped default name

usage() {
  cat <<'EOF'
saveclip2img — Save Windows-clipboard image

Usage:
  saveclip2img [OPTIONS]

Options:
  -q NUM    JPEG quality 0-100 (default 100)
  -p        Save as lossless PNG instead of JPEG
  -o FILE   Custom destination (absolute or relative)
  -h        Show this help

Examples:
  saveclip2img          # -> ~/shared/saved/260921_143022_image.jpg (Q100)
  saveclip2img -q 92    # JPEG at quality 92
  saveclip2img -p       # -> ~/shared/saved/260921_143022_image.png
  saveclip2img -o /tmp/a.jpg

Notes:
  Reads the image on the (WSLg) clipboard, prefers PNG > BMP > JPEG transport.
  Depends on: wl-clipboard (wl-paste) + ImageMagick (magick).
  Exit codes: 0 = saved, 1 = no image on clipboard or conversion failed, 2 = bad usage.
EOF
  exit "${1:-0}"
}

say_saved() {                                # clickable 3-line 'saved:' block; plain when piped
  if [ -t 1 ]; then
    local uri dir_win
    uri="file:///$(wslpath -m "$1")"          # Windows path -> Ctrl+click opens
    dir_win="$(wslpath -m "$(dirname "$1")")"
    printf '\e]8;;%s\e\\saved: %s\e]8;;\e\\\n'        "$uri" "$(basename "$1")"
    printf '\e]8;;file:///%s/\e\\folder: %s\e]8;;\e\\\n' "$dir_win" "$dir_win"
    printf '\e]8;;%s\e\\%s\e]8;;\e\\\n'              "$uri" "$1"
  else
    echo "saved: $1"
  fi
}

while getopts "q:po:h" o; do case "$o" in
  q) q=$OPTARG ;;
  p) png=1 ;;
  o) out=$OPTARG ;;
  h) usage 0 ;;
  *) usage 2 ;;
esac; done

pull=""                                                # Windows-direct pull file (PNG) - primary
win_temp="$(wslpath "$(powershell.exe -NoProfile -Command '$env:TEMP' 2>/dev/null | tr -d '\r' || true)" 2>/dev/null || true)"
if [ -n "$win_temp" ]; then
  ps_win="$(wslpath -w "$win_temp" 2>/dev/null || true)"
  if [ -n "$ps_win" ]; then
    pull_file="$win_temp/saveimg_pull.png"
    if powershell.exe -NoProfile -STA -Command "Add-Type -AssemblyName System.Windows.Forms; if ([System.Windows.Forms.Clipboard]::ContainsImage()) { [System.Windows.Forms.Clipboard]::GetImage().Save('$ps_win\\saveimg_pull.png',[System.Drawing.Imaging.ImageFormat]::Png) }" >/dev/null 2>&1 && [ -s "$pull_file" ]; then
      pull="$pull_file"
    fi
  fi
fi

types="$(wl-paste --list-types 2>/dev/null || true)"    # what does the WSLg bridge offer?
chosen=""
if [ -z "$pull" ]; then                                 # Windows pull failed -> last-resort WSLg read
  for t in image/png image/bmp image/jpeg; do
    grep -qx "$t" <<<"$types" && { chosen=$t; break; }
  done
fi

[ -n "$pull" ] || [ -n "$chosen" ] || { echo "saveclip2img: no image on clipboard (only text) - re-copy the image" >&2; exit 1; }

if [ -z "$out" ]; then
  dir="$HOME/shared/saved"
  ext=jpg; [ "$png" = 1 ] && ext=png
  stamp="$(date +%y%m%d_%H%M%S)"
  out="$dir/${stamp}_image.$ext"
fi
mkdir -p "$(dirname "$out")"

if [ -n "$pull" ]; then                                 # Windows-direct PNG (primary, reliable)
  if [ "$png" = 1 ]; then                               # lossless: only strip metadata
    magick "$pull" -strip "$out"
  else                                                  # JPEG: quality + full 4:4:4 color
    magick "$pull" -quality "$q" -sampling-factor 4:4:4 -strip "$out"
  fi
  rm -f "$pull"
elif [ "$png" = 1 ]; then                               # WSLg bridge: lossless passthrough
  wl-paste -t "$chosen" | magick - -strip "$out"
else                                                    # WSLg bridge: JPEG
  wl-paste -t "$chosen" | magick - -quality "$q" -sampling-factor 4:4:4 -strip "$out"
fi

[ -s "$out" ] || { [ -n "$pull" ] && rm -f "$pull"; echo "saveclip2img: save failed (nothing written)" >&2; exit 1; }
say_saved "$out"