#!/usr/bin/env bash
# saveimg - save the Windows-clipboard image as JPG/PNG into the shared data dir
#
# Reads whatever image is on the (WSLg) clipboard, prefers the most efficient
# transport type offered (PNG > BMP > JPEG), and writes a high-quality JPEG
# (default) or lossless PNG to ~/shared/saved/images/ with a WhatsApp-style
# timestamped name.
#
# Examples:
#   saveimg                # -> ~/shared/saved/images/image_203012_130926.jpg (Q100)
#   saveimg -q 92          # JPEG at quality 92 (eye-identical, ~1/8 the size)
#   saveimg -p             # save as lossless PNG (best for text/UI screenshots)
#   saveimg -o /tmp/a.jpg  # custom destination (absolute or relative)
#   saveimg -h             # this help
#
# Depends on: wl-clipboard (wl-paste) + ImageMagick (magick) - both installed by install.sh.
# Exit codes: 0 = saved, 1 = no image on clipboard or conversion failed, 2 = bad usage.

set -uo pipefail

q=100      # JPEG quality 0-100; 100 = near-lossless master, 92 = tiny but eye-identical
png=0      # 1 = PNG output (lossless); 0 = JPEG
out=""     # custom destination; empty = timestamped default name

usage() { awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 && !/^#/ {exit}' "$0"; exit 0; }

while getopts "q:po:h" o; do case "$o" in
  q) q=$OPTARG ;;
  p) png=1 ;;
  o) out=$OPTARG ;;
  h) usage ;;
  *) usage ;;
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

[ -n "$pull" ] || [ -n "$chosen" ] || { echo "saveimg: no image on clipboard (only text) - re-copy the image" >&2; exit 1; }

if [ -z "$out" ]; then
  dir="$HOME/shared/saved/images"
  ext=jpg; [ "$png" = 1 ] && ext=png
  out="$dir/image_$(date +%H%M%S)_$(date +%y%m%d).$ext"
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

[ -s "$out" ] || { [ -n "$pull" ] && rm -f "$pull"; echo "saveimg: save failed (nothing written)" >&2; exit 1; }
echo "saved: $out"