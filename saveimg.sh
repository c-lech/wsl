#!/bin/bash
# saveimg - save the Windows-clipboard image as JPG/PNG into the shared projects dir
#
# Reads whatever image is on the (WSLg) clipboard, prefers the most efficient
# transport type offered (PNG > BMP > JPEG), and writes a high-quality JPEG
# (default) or lossless PNG to ~/projects/saved/images/ with a WhatsApp-style
# timestamped name.
#
# Examples:
#   saveimg                # -> ~/projects/saved/images/image_203012_130926.jpg (Q100)
#   saveimg -q 92          # JPEG at quality 92 (eye-identical, ~1/8 the size)
#   saveimg -p             # save as lossless PNG (best for text/UI screenshots)
#   saveimg -o /tmp/a.jpg  # custom destination (absolute or relative)
#   saveimg -h             # this help
#
# Depends on: wl-clipboard (wl-paste) + ImageMagick (magick) - both installed by install.sh.
# Exit codes: 0 = saved, 1 = no image on clipboard or conversion failed, 2 = bad usage.

set -euo pipefail

q=100      # JPEG quality 0-100; 100 = near-lossless master, 92 = tiny but eye-identical
png=0      # 1 = PNG output (lossless); 0 = JPEG
out=""     # custom destination; empty = timestamped default name

usage() { sed -n '2,14p' "$0" | sed 's/^# *//'; exit 0; }

while getopts "q:po:h" o; do case "$o" in
  q) q=$OPTARG ;;
  p) png=1 ;;
  o) out=$OPTARG ;;
  h) usage ;;
  *) usage ;;
esac; done

types="$(wl-paste --list-types 2>/dev/null || true)"    # what does the clipboard offer?
chosen=""
for t in image/png image/bmp image/jpeg; do
  grep -qx "$t" <<<"$types" && { chosen=$t; break; }
done
[ -n "$chosen" ] || { echo "saveimg: no image on clipboard (only text) - re-copy the image" >&2; exit 1; }

if [ -z "$out" ]; then
  dir="$HOME/projects/saved/images"
  ext=jpg; [ "$png" = 1 ] && ext=png
  out="$dir/image_$(date +%H%M%S)_$(date +%y%m%d).$ext"
fi
mkdir -p "$(dirname "$out")"

if [ "$png" = 1 ]; then                                  # lossless: only strip metadata
  wl-paste -t "$chosen" | magick - -strip "$out"
else                                                     # JPEG: quality + full 4:4:4 color
  wl-paste -t "$chosen" | magick - -quality "$q" -sampling-factor 4:4:4 -strip "$out"
fi
echo "saveimg: $out"