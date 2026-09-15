#!/bin/bash
TEXT="${1:-Hello}"
FONTS_DIR="${2:-/usr/local/share/tdfiglet/fonts}"

i=1
for font in "$FONTS_DIR"/*.tdf; do
  name="$(basename "$font")"
  echo "=== #$i: tdfiglet -f $name '$TEXT' ==="
  tdfiglet -f "$font" "$TEXT"
  echo
  i=$((i+1))
done

echo "Total: $((i-1)) fonts"
