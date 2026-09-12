#!/bin/bash

IMG="${1:-$HOME/.config/fastfetch/logo.png}"
SIZE="${2:-60x30}"

command -v jp2a >/dev/null 2>&1 || {
  echo "jp2a is not installed. Run: sudo apt install -y jp2a" >&2
  exit 1
}

[ -f "$IMG" ] || {
  echo "Source image not found: $IMG" >&2
  exit 1
}

TMP=""
case "$IMG" in
  *.jpg|*.jpeg|*.JPG|*.JPEG)
    TMP="$IMG"
    ;;
  *)
    command -v convert >/dev/null 2>&1 || {
      echo "jp2a reads JPEG only; ImageMagick (convert) is required to convert $IMG. Run: sudo apt install -y imagemagick" >&2
      exit 1
    }
    TMP="$(mktemp --suffix=.jpg)"
    trap 'rm -f "$TMP"' EXIT
    convert "$IMG" -quality 95 "$TMP" || exit 1
    ;;
esac

i=1
run() {
  local label="$1"
  shift
  echo "=== #$i: jp2a $label $IMG ==="
  jp2a "$@"
  echo ""
  i=$((i+1))
}

MODES=("" "--colors" "--colors --grayscale")

CHARSETS=(
  "   ...',;:clodxkO0KXNWM"
  "@%#*+=-:. "
  " .:-=+*#%@"
  "MMWWNNK0X0xOocclid;;:,. "
  "█▓▒░ "
  "██▓▒░@%#*"
  "MMMMMMMM0Xxlio:. "
  "*o.: "
  "..:,;"
  "\\/|-_"
  "#@%*+=-:. "
  "XO0xcli. "
  "WNM0Xcli. "
  "888@@##"
  "@@@###$$$"
  "O0o."
  "+*."
  "·.,:;"
)

for mode in "${MODES[@]}"; do
  for chars in "${CHARSETS[@]}"; do
    run "--size=$SIZE $mode --chars='$chars'" --size="$SIZE" $mode --chars="$chars" "$TMP"
  done
done

for bg in light dark; do
  for chars in "${CHARSETS[0]}" "${CHARSETS[1]}" "${CHARSETS[3]}" "${CHARSETS[5]}" "${CHARSETS[6]}" "${CHARSETS[7]}"; do
    run "--size=$SIZE --colors --background=$bg --chars='$chars'" --size="$SIZE" --colors --background="$bg" --chars="$chars" "$TMP"
  done
done

run "--size=$SIZE --border" --size="$SIZE" --border "$TMP"
run "--size=$SIZE --border --colors" --size="$SIZE" --border --colors "$TMP"
run "--size=$SIZE --invert" --size="$SIZE" --invert "$TMP"
run "--size=$SIZE --invert --colors" --size="$SIZE" --invert --colors "$TMP"
for flip in --flipx --flipy "--flipx --flipy"; do
  for color in "" "--colors"; do
    run "--size=$SIZE $flip $color" --size="$SIZE" $flip $color "$TMP"
  done
done

echo "Total: $((i-1)) variations"