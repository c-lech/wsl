#!/bin/bash

set -euo pipefail

BRANCH=$(git rev-parse --abbrev-ref HEAD)
REMOTE=$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || echo "")

echo "Branch: $BRANCH"
echo

if git status --porcelain | grep -q .; then
  echo "Changed files:"
  git status --short
  echo
fi

if [ -n "$REMOTE" ]; then
  AHEAD=$(git rev-list --count @{upstream}..HEAD)
  BEHIND=$(git rev-list --count HEAD..@{upstream})
  if [ "$AHEAD" -gt 0 ]; then
    echo "Need to push ($AHEAD commit(s)):"
    git log --oneline @{upstream}..HEAD
    echo
  fi
  if [ "$BEHIND" -gt 0 ]; then
    echo "Need to pull ($BEHIND commit(s))"
    echo
  fi
  if [ "$AHEAD" -eq 0 ] && [ "$BEHIND" -eq 0 ] && ! git status --porcelain | grep -q .; then
    echo "All clean, nothing to push or pull."
  fi
else
  echo "No remote configured for this branch; nothing to push or pull against."
fi