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
  sshpass
  figlet
  cmatrix
)

sudo apt update

for pkg in "${packages[@]}"; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    echo "  -> Installing $pkg"
    sudo apt install -y "$pkg"
  else
    echo "  -> $pkg already installed"
  fi
done

# opencode

if [ -x "$HOME/.opencode/bin/opencode" ] || command -v opencode >/dev/null 2>&1; then
  echo "  -> opencode already installed"
else
  echo "  -> Installing opencode"
  curl -fsSL https://opencode.ai/install | bash
  source ~/.bashrc
fi

echo "[+] Installing dotfiles"

ln -sfn "$BASE/dotfiles/tmux.conf" ~/.tmux.conf


echo "[+] Creating projects directory"

mkdir -p "$BASE/projects"


echo "[+] Done"
