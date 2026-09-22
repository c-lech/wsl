#!/usr/bin/env bash
# savetxt2img — Render Windows-clipboard text as a styled source-code image

set -uo pipefail

lang="markdown"   # default near-plain grammar; override with -l (python, bash, json, ...)
out=""            # custom destination; empty = timestamped default name

usage() {
  cat <<'EOF'
savetxt2img — Render Windows-clipboard text as a styled source-code image

Usage:
  savetxt2img [OPTIONS]

Options:
  -l LANG     Grammar for syntax highlighting (default: markdown)
  -o FILE     Custom destination (absolute or relative)
  -h          Show this help

Examples:
  savetxt2img            # -> ~/shared/saved/260921_143022_txt.png (markdown-ish plain)
  savetxt2img -l python  # Python syntax highlight
  savetxt2img -l bash    # shell snippet render
  savetxt2img -l json    # JSON render
  savetxt2img -o /tmp/x.png

Notes:
  Reads text/plain from the (WSLg) clipboard, strips Windows CR endings, renders
  with silicon (OneHalfDark, drop-shadow, no window bar, line numbers on).
  Depends on: wl-clipboard (wl-paste) + silicon - both installed by install.sh.
  Exit codes: 0 = saved, 1 = no text on clipboard or render failed, 2 = bad usage.
EOF
  exit 0
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
[ -n "$text" ] || { echo "savetxt2img: no text on clipboard - re-copy the code" >&2; exit 1; }

if [ -z "$out" ]; then
  auto=1            # auto-named output (removable on failure; never touch a custom -o)
  dir="$HOME/shared/saved"
  stamp="$(date +%y%m%d_%H%M%S)"
  out="$dir/${stamp}_txt.png"    # WhatsApp-style timestamped PNG
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
  echo "savetxt2img: render failed - $render_out" >&2
  exit 1
fi
[ -s "$out" ] || { echo "savetxt2img: render failed (no output file)" >&2; exit 1; }
say_saved "$out"