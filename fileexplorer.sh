#!/usr/bin/env bash
# fileexplorer — Browse files full-screen (images via chafa, text shown); Enter opens safe ones in Windows

set -uo pipefail

DIR="$HOME/shared/saved"

# Extensions safe to hand to Windows; everything else is refused.
SAFE_EXT="txt md json csv log sh py png jpg jpeg gif bmp webp svg pdf docx xlsx zip mp4 mp3"

usage() {
  cat <<'EOF'
fileexplorer — Browse files full-screen; Enter opens safe ones in Windows

Usage:
  fileexplorer [OPTIONS]

Options:
  -h, --help          Show this help
  -d, --directory P   Browse P instead of ~/shared/saved
  -l, --list          Print the listing, no picker

Examples:
  fileexplorer
  fileexplorer -d /mnt/c/Users/benito/Desktop/escritorio

Notes:
  Enter opens only whitelisted list types; exe/com/bat/cmd/ps1/msi refused.
  Ctrl+C copies the file to the Windows clipboard (text or image).
  Ctrl+X deletes the file (Windows Recycle Bin, needs a Windows path).
  Exit codes: 0 = ok, 1 = dir not found / no files, 2 = bad usage.
EOF
  exit 0
}

die() {
  echo "fileexplorer: $1" >&2
  exit "${2:-1}"
}

usage_error() {
  echo "fileexplorer: $1 (see fileexplorer -h)" >&2
  exit 2
}

while (($# > 0)); do
  case "$1" in
    -h|--help)   usage ;;
    -d|--directory)
      [[ $# -ge 2 && -n "$2" ]] || usage_error "$1 needs a path"
      DIR="$2"; shift 2 ;;
    --directory=*)
      [[ -n "${1#*=}" ]] || usage_error "--directory needs a path"
      DIR="${1#*=}"; shift ;;
    -l|--list)   LIST=1; shift ;;
    *)           usage_error "unknown option: '$1'" ;;
  esac
done

[ -d "$DIR" ] || die "dir not found: $DIR" 1

status() {
  printf '\033[%d;1H\033[2K\033[2m%s\033[0m' "$rows" "${1:0:56}"
}

render_footer() {
  status "$((idx+1))/$n  ${name:0:32}  ←→ browse · enter=open · ^c=copy · ^x=del · q/esc=quit"
}

build_lines() {
  local f size date
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    size=$(stat -c %s "$f" 2>/dev/null || echo 0)
    date=$(stat -c %y "$f" 2>/dev/null || echo "?")
    date=${date%%.*}
    printf '%s\t%s\t%s\t%s\n' "$(basename "$f")" "$size" "${date:-?}" "$f"
  done < <(find "$DIR" -maxdepth 1 -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | sed 's/^[^ ]* //')
}

open_in_windows() {
  local f=$1 real ext e found=0 wpath
  [ -f "$f" ] || return 1
  real=$(realpath "$f" 2>/dev/null) || return 1
  [ -f "$real" ] || return 1
  ext=${real##*.}
  ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
  for e in $SAFE_EXT; do
    [ "$ext" = "$e" ] && { found=1; break; }
  done
  [ "$found" = 1 ] || return 1
  wpath=$(wslpath -w "$real" 2>/dev/null) || return 1
  ( cd /mnt/c 2>/dev/null; cmd.exe /c start '' "$wpath" )
}

copy_to_clipboard() {
  local f=$1 ext wpath
  ext=${f##*.}
  ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
  case "$ext" in
    txt|md|json|csv|log|sh|py)
      clip.exe < "$f" 2>/dev/null
      ;;
    png|jpg|jpeg|gif|bmp|webp|svg)
      wpath=$(wslpath -w "$f" 2>/dev/null) || return 1
      powershell.exe -Sta -NoProfile -Command \
        "Add-Type -AssemblyName System.Windows.Forms; \$b = [System.Drawing.Image]::FromFile('$wpath'); [System.Windows.Forms.Clipboard]::SetImage(\$b); \$b.Dispose()" \
        >/dev/null 2>&1
      ;;
    *) return 1 ;;
  esac
}

delete_to_recyclebin() {
  local f=$1 wp
  [ -f "$f" ] || return 1
  wp=$(wslpath -w "$f" 2>/dev/null) || return 1
  [[ "$wp" == \\\\* ]] && return 1
  powershell.exe -NoProfile -Command \
    "Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile('$wp','OnlyErrorDialogs','SendToRecycleBin')" \
    >/dev/null 2>&1
}

if [ -n "${LIST:-}" ]; then
  build_lines
  exit 0
fi

command -v chafa >/dev/null 2>&1 || die "chafa is not installed (apt install chafa)" 1

mapfile -t files < <(build_lines)
((${#files[@]} > 0)) || die "no files in $DIR" 1

n=${#files[@]}
idx=0

stty -icanon -echo -isig
trap 'stty sane; exit 0' EXIT TERM
on_int() { copy_to_clipboard "$path" && status "copied: ${name:0:32}" || status "not copied: ${name:0:32}"; }
trap on_int INT

while true; do
  line=${files[idx]}
  path=$(printf '%s\n' "$line" | cut -f4)
  name=${path##*/}
  rows=$(tput lines 2>/dev/null || echo 40)
  clear 2>/dev/null || true

  case "$path" in
    *.png|*.jpg|*.jpeg|*.gif|*.bmp|*.webp|*.svg)
      chafa "$path" 2>/dev/null || echo "fileexplorer: cannot render $name" >&2
      ;;
    *.txt|*.md|*.json|*.csv|*.log|*.sh|*.py)
      printf '\033[1m%s\033[0m  ·  %s bytes  ·  %s\n\n' "$name" \
        "$(printf '%s' "$line" | cut -f2)" "$(printf '%s' "$line" | cut -f3)"
      sed -n "1,$(( rows - 6 ))p" "$path" 2>/dev/null
      ;;
    *)
      printf '\033[2m%s · %s bytes · no preview\033[0m\n' "$name" "$(printf '%s' "$line" | cut -f2)"
      ;;
  esac

  render_footer

  while true; do
    IFS= read -rsN1 key || { printf '\n'; exit 0; }
    case "$key" in
      $'\e')
        IFS= read -t 0.1 -rsn1 a
        [ -n "$a" ] || { printf '\n'; exit 0; }
        if [ "$a" = '[' ]; then
          IFS= read -rsn1 b
          case "$b" in
            'C'|'B') idx=$(( (idx + 1) % n )); break ;;
            'D'|'A') idx=$(( (idx - 1 + n) % n )); break ;;
          esac
        fi
        ;;
      $'\r'|$'\n')
        if open_in_windows "$path"; then
          status "opened: ${name:0:32}"
        else
          status "not opened: ${name:0:32}"
        fi
        ;;
      $'\x03')
        if copy_to_clipboard "$path"; then
          status "copied: ${name:0:32}"
        else
          status "not copied: ${name:0:32}"
        fi
        ;;
      $'\x18')
        status "delete \"${name:0:28}\"? x=confirm · any other key=cancel"
        IFS= read -rsN1 k2 || { printf '\n'; exit 0; }
        if [ "$k2" = 'x' ] || [ "$k2" = 'X' ]; then
          if delete_to_recyclebin "$path"; then
            new=(); l=
            for l in "${files[@]}"; do
              [ "$l" != "$line" ] && new+=("$l")
            done
            files=("${new[@]}")
            n=${#files[@]}
            ((n > 0)) || { printf '\n'; exit 0; }
            idx=$(( idx >= n ? n - 1 : idx ))
            break
          else
            status "recycle bin unavailable: ${name:0:32}"
          fi
        else
          render_footer
        fi
        ;;
      q|Q)
        printf '\n'
        exit 0
        ;;
    esac
  done
done