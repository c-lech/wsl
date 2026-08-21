#!/bin/bash

set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

  local packages=(jq zstd tree figlet cmatrix mc \
    mtr nmap netcat-openbsd traceroute dnsutils whois telnet socat iftop net-tools \
    htop btop glances ncdu nvtop iotop sysstat lm-sensors smartmontools snmp \
    ansible sshpass rsync fzf wl-clipboard)

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
    if ! curl -fsSL https://opencode.ai/install | bash; then
      step "Official installer unavailable, downloading from GitHub releases"
      mkdir -p "$HOME/.opencode/bin"
      curl -fL "https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-x64.tar.gz" \
        | tar xz -C "$HOME/.opencode/bin"
    fi
    step "Done"
  fi

  step "Linking opencode to /usr/local/bin"
  sudo ln -sfn "$HOME/.opencode/bin/opencode" /usr/local/bin/opencode
}

install_tmuxai() {
  item "tmuxai"
  if command -v tmuxai >/dev/null 2>&1; then
    step "Already installed ($(tmuxai --version 2>/dev/null || echo 'unknown version')), skipping"
  else
    step "Installing tmuxai"
    if ! curl -fsSL https://get.tmuxai.dev | bash; then
      step "Official installer unavailable, downloading from GitHub releases"
      curl -fL "https://github.com/alvinunreal/tmuxai/releases/latest/download/tmuxai_Linux_amd64.tar.gz" \
        | sudo tar xz -C /usr/local/bin --strip-components=0 tmuxai
    fi
    step "Done"
  fi
}

install_ollama() {
  item "ollama"
  if command -v ollama >/dev/null 2>&1; then
    step "Already installed ($(ollama --version 2>/dev/null || echo 'unknown version')), skipping"
  else
    step "Installing ollama"
    if ! curl -fsSL https://ollama.com/install.sh | sh; then
      step "Official installer unavailable, downloading from GitHub releases"
      curl -fL "https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64" \
        -o /tmp/ollama
      sudo install -o root -g root -m 755 /tmp/ollama /usr/local/bin/ollama
      rm -f /tmp/ollama
    fi
    step "Done"
  fi

  if ollama list 2>/dev/null | grep -q 'qwen3:8b'; then
    step "Model qwen3:8b already pulled, skipping"
  else
    step "Pulling qwen3:8b"
    ollama pull qwen3:8b
    printf 'FROM qwen3:8b\nPARAMETER num_ctx 16384\n' > /tmp/Modelfile-qwen3-16k
    ollama create qwen3:8b-16k -f /tmp/Modelfile-qwen3-16k
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
    RESTART_NEEDED=1
  fi

  item "virtualbox_WSL2 plugin"
  if command -v vagrant >/dev/null 2>&1 && vagrant plugin list | grep -qi virtualbox_wsl2; then
    step "Already installed, skipping"
  elif command -v vagrant >/dev/null 2>&1; then
    step "Installing"
    vagrant plugin install virtualbox_WSL2
    step "Done"
    RESTART_NEEDED=1
  else
    step "Skipped (vagrant not found in PATH)"
  fi
}

install_tmux_plugins() {
  item "tmux plugins"
  if [ -d "$HOME/.tmux/plugins/tpm" ]; then
    step "TPM already installed, skipping"
  else
    step "Cloning tpm"
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    step "Installing plugins"
    "$HOME/.tmux/plugins/tpm/bin/install_plugins"
    step "Done"
  fi
}

install_dotfiles() {
  item "Installing dotfiles"
  step "Linking ~/.tmux.conf -> $BASE/dotfiles/tmux.conf"
  ln -sfn "$BASE/dotfiles/tmux.conf" "$HOME/.tmux.conf"
  step "Linking ~/.bashrc -> $BASE/dotfiles/bashrc"
  ln -sfn "$BASE/dotfiles/bashrc" "$HOME/.bashrc"
  step "Linking ~/.bash_aliases -> $BASE/dotfiles/bash_aliases"
  ln -sfn "$BASE/dotfiles/bash_aliases" "$HOME/.bash_aliases"
  step "Linking ~/.config/opencode/opencode.jsonc -> $BASE/dotfiles/opencode.jsonc"
  mkdir -p "$HOME/.config/opencode"
  ln -sfn "$BASE/dotfiles/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"
  step "Linking ~/.config/tmuxai/config.yaml -> $BASE/dotfiles/tmuxai.yaml"
  mkdir -p "$HOME/.config/tmuxai"
  ln -sfn "$BASE/dotfiles/tmuxai.yaml" "$HOME/.config/tmuxai/config.yaml"
  install_wslconfig
  step "Done"
}

install_wslconfig() {
  step "Configuring Windows .wslconfig"
  if ! command -v cmd.exe >/dev/null 2>&1 || ! command -v wslpath >/dev/null 2>&1; then
    step "Not running on WSL (cmd.exe/wslpath not found), skipping"
    return
  fi

  local win_home win_config
  win_home="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
  if [ -z "$win_home" ]; then
    step "Could not detect Windows profile, skipping"
    return
  fi

  win_config="$(wslpath -u "$win_home")/.wslconfig"
  if [ ! -d "$(dirname "$win_config")" ]; then
    step "Windows profile not reachable ($win_config), skipping"
    return
  fi

  if [ -f "$win_config" ]; then
    if cmp -s "$BASE/dotfiles/wslconfig" "$win_config"; then
      step "Already in sync, skipping"
    else
      step "Updating $win_config"
      cp "$BASE/dotfiles/wslconfig" "$win_config"
      RESTART_NEEDED=1
    fi
  else
    step "Installing $win_config"
    cp "$BASE/dotfiles/wslconfig" "$win_config"
    RESTART_NEEDED=1
  fi
}

mount_data_dir() {
  item "mount data"

  if mountpoint -q "$HOME/projects"; then
    step "Already mounted, skipping"
  else
    step "Creating mount point $HOME/projects"
    mkdir -p "$HOME/projects"

    local uid gid
    uid="$(id -u)"
    gid="$(id -g)"
    step "Mounting C:\\data\\projects -> $HOME/projects (uid=$uid, gid=$gid)"
    sudo mount -t drvfs -o "defaults,metadata,uid=$uid,gid=$gid" 'C:\data\projects' "$HOME/projects"
    sleep 2
    step "Done"
  fi

  if ! grep -Fq 'C:\data\projects' /etc/fstab 2>/dev/null; then
    local uid gid
    uid="$(id -u)"
    gid="$(id -g)"
    step "Adding $HOME/projects to /etc/fstab (persistent)"
    echo "C:\\data\\projects $HOME/projects drvfs defaults,metadata,uid=$uid,gid=$gid 0 0" | sudo tee -a /etc/fstab
  fi
}

install_ssh() {
  item "SSH keys"
  local src="$HOME/projects/infra/wsl_ssh_key"
  if [ ! -f "$src/id_ed25519" ]; then
    step "Source key not found at $src/id_ed25519, skipping"
    return
  fi
  step "Creating ~/.ssh"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  step "Copying id_ed25519"
  cp "$src/id_ed25519" "$HOME/.ssh/"
  chmod 600 "$HOME/.ssh/id_ed25519"
  step "Copying id_ed25519.pub"
  cp "$src/id_ed25519.pub" "$HOME/.ssh/"
  chmod 644 "$HOME/.ssh/id_ed25519.pub"
  step "Done"
}

configure_timezone() {
  item "timezone"
  local tz="America/Argentina/Buenos_Aires"
  if [ "$(timedatectl show -p Timezone --value 2>/dev/null)" = "$tz" ]; then
    step "Already set to $tz, skipping"
  else
    step "Setting timezone to $tz"
    sudo timedatectl set-timezone "$tz" \
      || { step "timedatectl failed, linking /etc/localtime directly"
           sudo ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime; }
    step "Done (now: $(date))"
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
  RESTART_NEEDED=0

  configure_timezone
  install_packages
  install_opencode
  install_tmuxai
  #install_ollama
  install_vagrant
  install_dotfiles
  install_tmux_plugins
  configure_git
  mount_data_dir
  install_ssh

  item "Setup complete"
  step "All steps done"
  echo
  hr
  echo
  if [ "$RESTART_NEEDED" = 1 ]; then
    echo "  Run 'wsl --shutdown' in PowerShell and reopen to apply changes."
  fi
  echo
}

main "$@"
