#!/bin/bash
# serve - static file server, first free port from 8000 up

usage() {
  cat <<'EOF'
serve — Serve the current directory over HTTP on the first free port from 8000

Usage:
  serve [OPTIONS]

Options:
  -h, --help      Show this help

Examples:
  serve           # 8000 if free, otherwise 8001, 8002, ...
  serve -h        # this help

Notes:
  Ctrl+C to stop.
EOF
  exit 0
}

case "${1:-}" in -h|--help) usage ;; esac

port=8000
while [ "$port" -lt 8100 ] && ss -tlnH "sport = :$port" | grep -q .; do
  port=$((port + 1))
done
[ "$port" -ge 8100 ] && { echo "serve: no free port in 8000-8099" >&2; exit 1; }

echo "serve: http://127.0.0.1:$port  ($PWD)"
exec python3 -m http.server "$port" --bind 127.0.0.1