#!/bin/bash

set -euo pipefail

MESSAGE="${1:-update}"

git add .

if git diff --cached --quiet; then
  echo "No changes to commit"
  exit 1
fi

git commit -m "$MESSAGE"
git push
