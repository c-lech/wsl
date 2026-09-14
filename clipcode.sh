#!/bin/bash
# clipcode - render the Windows-clipboard code/text as a PNG with silicon into the shared projects dir
#
# Reads whatever text/code is on the (WSLg) clipboard as text/plain, strips
# Windows CR line endings, and renders it with silicon to a lossless PNG with
# OneHalfDark theme, drop-shadow (no window bar), line numbers on, timestamped
# into ~/projects/clipboard/code/.
#
# Examples:
#   clipcode                # -> ~/projects/clipboard/code/code_203012_130926.png (markdown-ish plain)
#   clipcode -l python      # Python syntax highlight
#   clipcode -l bash        # shell snippet render
#   clipcode -l json        # JSON render
#   clipcode -o /tmp/x.png  # custom destination (absolute or relative)
#   clipcode -h             # this help
#
# Depends on: wl-clipboard (wl-paste) + silicon - both installed by install.sh.
# Exit codes: 0 = saved, 1 = no text on clipboard or render failed, 2 = bad usage.

set -euo pipefail

lang="markdown"   # default near-plain grammar; override with -l (python, bash, json, ...)
out=""            # custom destination; empty = timestamped default name

usage() { sed -n '2,15p' "$0" | sed 's/^# *//'; exit 0; }

while getopts "l:o:h" o; do case "$o" in
  l) lang=$OPTARG ;;
  o) out=$OPTARG ;;
  h) usage ;;
  *) usage ;;
esac; done

text="$(wl-paste 2>/dev/null || true)"          # nothing full-text on the clipboard?
[ -n "$text" ] || { echo "clipcode: no text on clipboard - re-copy the code" >&2; exit 1; }

if [ -z "$out" ]; then
  auto=1            # auto-named output (removable on failure; never touch a custom -o)
  dir="$HOME/projects/clipboard/code"
  out="$dir/code_$(date +%H%M%S)_$(date +%y%m%d).png"   # WhatsApp-style timestamped PNG
fi
mkdir -p "$(dirname "$out")"
[ -z "${auto:-}" ] || rm -f "$out"                      # drop stale auto name so -s can't false-pass

render_out="$(printf '%s\n' "$text" | tr -d '\r' | silicon \
  -l "$lang" \
  --theme OneHalfDark \
  -b '#282c34' \
  --no-window-controls \
  --shadow-blur-radius 24 --shadow-color '#000000' --shadow-offset-y 8 \
  --pad-horiz 40 --pad-vert 60 \
  -o "$out" 2>&1 || true)"                              # silicon exits 0 even on real failure

if printf '%s\n' "$render_out" | grep -qi '\[error\]'; then
  [ -z "${auto:-}" ] || rm -f "$out"                    # don't remove a pre-existing custom -o
  echo "clipcode: render failed - $render_out" >&2
  exit 1
fi
[ -s "$out" ] || { echo "clipcode: render failed (no output file)" >&2; exit 1; }
echo "clipcode: $out"