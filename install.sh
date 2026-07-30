#!/bin/bash

set -e

BASE=~/wsl

echo "[+] Update package list"

sudo apt update

echo "[+] Installing packages"

packages=(
  jq
  tree
  ansible
)

sudo apt update

for pkg in "${packages[@]}"; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    sudo apt install -y "$pkg"
  fi
done


echo "[+] Installing dotfiles"

ln -sfn "$BASE/dotfiles/tmux.conf" ~/.tmux.conf


echo "[+] Creating projects directory"

mkdir -p "$BASE/projects"


echo "[+] Done"
