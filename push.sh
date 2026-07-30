#!/bin/bash

set -e

MESSAGE="${1:-update}"

git add .
git commit -m "$MESSAGE"
git push
