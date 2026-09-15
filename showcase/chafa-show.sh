#!/bin/bash
# chafa-show - render a gallery of chafa symbol/color variations of an image
#
# Examples:
#   chafa-show.sh                        # fastfetch logo, 60x30
#   chafa-show.sh image_212026_260913.jpg          # any image, default size
#   chafa-show.sh image_212026_260913.jpg 80x40    # any image, custom size

IMG="${1:-$HOME/.config/fastfetch/logo.png}"   # image to show (default: fastfetch logo)
SIZE="${2:-60x30}"                             # target symbol-grid size, e.g. 80x40

[ -f "$IMG" ] || { echo "Source image not found: $IMG" >&2; exit 1; }

SYMBOLS="ascii block braille half hhalf vhalf quad sextant stipple dot diagonal geometric wedge border technical wide solid ugly inverted legacy extra"
COLORS="none 256 full"

i=1
for sym in $SYMBOLS; do
  for col in $COLORS; do
    echo "=== #$i: chafa -f symbols --symbols $sym -c $col -s $SIZE $IMG ==="
    chafa -f symbols --symbols "$sym" -c "$col" -s "$SIZE" "$IMG"
    echo
    i=$((i+1))
  done
done

for combo in "block+border" "half+border" "all-wide" "block+stipple" "half+geometric"; do
  for col in none full; do
    echo "=== #$i: chafa -f symbols --symbols $combo -c $col -s $SIZE $IMG ==="
    chafa -f symbols --symbols "$combo" -c "$col" -s "$SIZE" "$IMG"
    echo
    i=$((i+1))
  done
done

for flag in --fg-only --invert; do
  for sym in ascii block half braille; do
    echo "=== #$i: chafa -f symbols --symbols $sym -c full $flag -s $SIZE $IMG ==="
    chafa -f symbols --symbols "$sym" -c full $flag -s "$SIZE" "$IMG"
    echo
    i=$((i+1))
  done
done

echo "Total: $((i-1)) variations"