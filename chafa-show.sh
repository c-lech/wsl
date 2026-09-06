#!/bin/bash
IMG="$HOME/.config/fastfetch/logo.png"

SYMBOLS="ascii block braille half hhalf vhalf quad sextant stipple dot diagonal geometric wedge border technical wide solid ugly inverted legacy extra"
COLORS="none 256 full"

i=1
for sym in $SYMBOLS; do
  for col in $COLORS; do
    echo "=== #$i: chafa -f symbols --symbols $sym -c $col -s 60x30 $IMG ==="
    chafa -f symbols --symbols "$sym" -c "$col" -s 60x30 "$IMG"
    echo
    i=$((i+1))
  done
done

for combo in "block+border" "half+border" "all-wide" "block+stipple" "half+geometric"; do
  for col in none full; do
    echo "=== #$i: chafa -f symbols --symbols $combo -c $col -s 60x30 $IMG ==="
    chafa -f symbols --symbols "$combo" -c "$col" -s 60x30 "$IMG"
    echo
    i=$((i+1))
  done
done

for flag in --fg-only --invert; do
  for sym in ascii block half braille; do
    echo "=== #$i: chafa -f symbols --symbols $sym -c full $flag -s 60x30 $IMG ==="
    chafa -f symbols --symbols "$sym" -c full $flag -s 60x30 "$IMG"
    echo
    i=$((i+1))
  done
done

echo "Total: $((i-1)) variations"