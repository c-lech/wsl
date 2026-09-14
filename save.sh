#!/bin/bash
# save - detect what's on the Windows clipboard and dispatch to the right saver
#
# If the clipboard holds an image it runs saveimg.sh (-> ~/projects/saved/images/),
# if it holds text/code it runs savecode.sh (-> ~/projects/saved/code/ as PNG).
# Flags are forwarded to whichever engine runs; exit codes are inherited from it.
#
# Examples:
#   save                  # image -> saveimg, text -> savecode, auto
#   save -q 92            # image flag: JPEG quality 92
#   save -p               # image flag: lossless PNG
#   save -l python        # code flag: Python syntax highlight
#   save -o /tmp/x.png    # custom destination (both engines)
#   save -h               # this help
#   saveimg -h            # all image options
#   savecode -h           # all code options
#
# Depends on: wl-clipboard (wl-paste) + same deps as saveimg.sh/savecode.sh.
# Exit codes: 0 = saved, 1 = nothing on clipboard or save failed, 2 = bad usage (engine).

set -euo pipefail

if [ "${1:-}" = "-h" ]; then
  sed -n '2,18p' "$0" | sed 's/^# *//'
  exit 0
fi

types="$(wl-paste --list-types 2>/dev/null || true)"   # what does the clipboard offer?

chosen=""
for t in image/png image/bmp image/jpeg; do            # image beats text, png > bmp > jpeg
  grep -qx "$t" <<<"$types" && { chosen=$t; break; }
done

if [ -n "$chosen" ]; then
  exec "$HOME/wsl/saveimg.sh" "$@"
fi

grep -q "^text/" <<<"$types" && exec "$HOME/wsl/savecode.sh" "$@"

echo "save: no image or text on clipboard - re-copy first" >&2
exit 1