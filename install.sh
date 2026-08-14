#!/bin/bash

set -euo pipefail

BASE="$HOME/wsl"

section() {
  echo
  echo "================================================"
  echo
  echo "  $1"
  echo
  echo "================================================"
  echo
}

hr() {
  echo "================================================"
}

item() {
  echo
  hr
  echo
  echo "  $1"
  echo
}

step() {
  echo "  -> $1"
}

install_packages() {
  section "Installing packages"

  step "Updating package lists (apt update)"
  sudo apt update

  local packages=(jq tree ansible sshpass figlet cmatrix)

  for pkg in "${packages[@]}"; do
    item "$pkg"
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      step "Already installed, skipping"
    else
      step "Installing $pkg"
      sudo apt install -y "$pkg"
      step "Done"
    fi
  done
}

install_opencode() {
  item "opencode"
  if [ -x "$HOME/.opencode/bin/opencode" ]; then
    step "Already installed, skipping"
  else
    step "Installing opencode"
    curl -fsSL https://opencode.ai/install | bash
    step "Done"
  fi
}

install_vagrant() {
  item "vagrant"
  if dpkg -s vagrant >/dev/null 2>&1; then
    step "Already installed, skipping"
  else
    local codename
    codename="$(lsb_release -cs 2>/dev/null || true)"
    if [ -z "$codename" ] || [ "$codename" = "sid" ] || [ "$codename" = "n/a" ]; then
      step "Codename '$codename' not supported by HashiCorp, using 'trixie'"
      codename="trixie"
    fi

    if [ ! -f /etc/apt/sources.list.d/hashicorp.list ]; then
      step "Adding HashiCorp repository ($codename)"
      curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $codename main" \
        | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
    else
      step "HashiCorp repository already configured"
    fi

    step "Updating package lists (apt update)"
    sudo apt update

    step "Installing vagrant"
    sudo apt install -y vagrant
    step "Done"
  fi

  item "virtualbox_WSL2 plugin"
  if command -v vagrant >/dev/null 2>&1 && vagrant plugin list | grep -qi virtualbox_wsl2; then
    step "Already installed, skipping"
  elif command -v vagrant >/dev/null 2>&1; then
    step "Installing"
    vagrant plugin install virtualbox_WSL2
    step "Done"
  else
    step "Skipped (vagrant not found in PATH)"
  fi
}

create_projects_dir() {
  item "projects directory"
  if [ -d "$BASE/projects" ]; then
    step "Already exists, skipping"
  else
    step "Creating $BASE/projects"
    mkdir -p "$BASE/projects"
    step "Done"
  fi
}

install_dotfiles() {
  item "Installing dotfiles"
  step "Linking ~/.tmux.conf -> $BASE/dotfiles/tmux.conf"
  ln -sfn "$BASE/dotfiles/tmux.conf" "$HOME/.tmux.conf"
  step "Linking ~/.bashrc -> $BASE/dotfiles/bashrc"
  ln -sfn "$BASE/dotfiles/bashrc" "$HOME/.bashrc"
  step "Done"
}

mount_data_dir() {
  item "mount data"
  if mountpoint -q /data; then
    step "Already mounted, skipping"
    return
  fi

  if [ -L /data ]; then
    step "Removing existing /data symlink"
    sudo rm -f /data
  fi

  step "Creating mount point /data"
  sudo mkdir -p /data

  step "Mounting C:\data -> /data"
  sudo mount -t drvfs 'C:\data' /data
  step "Done"

  if ! grep -Fq 'C:\data' /etc/fstab 2>/dev/null; then
    step "Adding /data to /etc/fstab (persistent)"
    echo 'C:\data /data drvfs defaults,metadata 0 0' | sudo tee -a /etc/fstab
  fi
}

configure_git() {
  item "git identity"
  if [ -n "$(git config --global user.name)" ] && [ -n "$(git config --global user.email)" ]; then
    step "Already configured ($(git config --global user.name) <$(git config --global user.email)>)"
  else
    step "Setting git identity"
    git config --global user.name "c-lech"
    git config --global user.email "126396070+c-lech@users.noreply.github.com"
    step "Done"
  fi
}

main() {
  install_packages
  install_opencode
  install_vagrant
  create_projects_dir
  install_dotfiles
  configure_git
  mount_data_dir

  item "Setup complete"
  step "All steps done"
}

main "$@"
