#!/bin/bash

set -e

BASE=~/wsl

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
    #source ~/.bashrc
  else
    echo "  -> $pkg already installed"
  fi
done

echo "[+] Installing dotfiles"

ln -sfn "$BASE/dotfiles/tmux.conf" ~/.tmux.conf
ln -sfn "$BASE/dotfiles/bashrc" ~/.bashrc
source ~/.bashrc

# opencode

#if [ -x "$HOME/.opencode/bin/opencode" ] || command -v opencode >/dev/null 2>&1; then
if [ -x "$HOME/.opencode/bin/opencode" ]; then
  echo "  -> opencode already installed"
else
  echo "  -> Installing opencode"
  curl -fsSL https://opencode.ai/install | bash
fi

echo "[+] Creating projects directory"

mkdir -p "$BASE/projects"

source ~/.bashrc
#hash -r

echo "[+] Done"
