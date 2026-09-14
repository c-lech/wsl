#!/usr/bin/env bash
# savecode - render the Windows-clipboard code/text as a PNG with silicon into the shared projects dir
#
# Reads whatever text/code is on the (WSLg) clipboard as text/plain, strips
# Windows CR line endings, and renders it with silicon to a lossless PNG with
# OneHalfDark theme, drop-shadow (no window bar), line numbers on, timestamped
# into ~/projects/saved/code/.
#
# Examples:
#   savecode                # -> ~/projects/saved/code/code_203012_130926.png (markdown-ish plain)
#   savecode -l python      # Python syntax highlight
#   savecode -l bash        # shell snippet render
#   savecode -l json        # JSON render
#   savecode -o /tmp/x.png  # custom destination (absolute or relative)
#   savecode -h             # this help
#
# Depends on: wl-clipboard (wl-paste) + silicon - both installed by install.sh.
# Exit codes: 0 = saved, 1 = no text on clipboard or render failed, 2 = bad usage.

set -uo pipefail

lang="markdown"   # default near-plain grammar; override with -l (python, bash, json, ...)
out=""            # custom destination; empty = timestamped default name

usage() { awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 && !/^#/ {exit}' "$0"; exit 0; }

while getopts "l:o:h" o; do case "$o" in
  l) lang=$OPTARG ;;
  o) out=$OPTARG ;;
  h) usage ;;
  *) usage ;;
esac; done

text="$(wl-paste 2>/dev/null || true)"          # nothing full-text on the clipboard?
if [ -z "$text" ]; then                          # WSLg bridge empty -> ask Windows directly
  text="$(powershell.exe -NoProfile -Command 'Get-Clipboard -Raw' 2>/dev/null | tr -d '\r' || true)"
fi
[ -n "$text" ] || { echo "savecode: no text on clipboard - re-copy the code" >&2; exit 1; }

if [ -z "$out" ]; then
  auto=1            # auto-named output (removable on failure; never touch a custom -o)
  dir="$HOME/projects/saved/code"
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
  echo "savecode: render failed - $render_out" >&2
  exit 1
fi
[ -s "$out" ] || { echo "savecode: render failed (no output file)" >&2; exit 1; }
echo "saved: $out"