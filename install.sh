#!/bin/bash

set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

section() {
  echo "================================================"
  echo "  $1"
  echo "================================================"
}

step() {
  echo "  -> $1"
}

install_packages() {
  section "Installing packages"

  step "apt update"
  sudo apt update

  local packages=(jq zstd tree figlet cmatrix mc \
    mtr nmap netcat-openbsd traceroute dnsutils whois telnet socat iftop net-tools \
    htop btop glances ncdu nvtop iotop sysstat lm-sensors smartmontools snmp \
    ansible sshpass rsync fzf wl-clipboard chafa)

  for pkg in "${packages[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      step "$pkg (already installed)"
    else
      step "$pkg"
      sudo apt install -y "$pkg"
    fi
  done
}

install_fastfetch() {
  if command -v fastfetch >/dev/null 2>&1; then
    step "fastfetch (already installed)"
  else
    step "fastfetch -> adding PPA"
    sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch
    step "fastfetch -> installing"
    sudo apt update && sudo apt install -y fastfetch
  fi
}

install_opencode() {
  if [ -x "$HOME/.opencode/bin/opencode" ]; then
    step "opencode (already installed)"
  else
    step "opencode -> installing"
    if ! curl -fsSL https://opencode.ai/install | bash; then
      mkdir -p "$HOME/.opencode/bin"
      curl -fL "https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-x64.tar.gz" \
        | tar xz -C "$HOME/.opencode/bin"
    fi
  fi
  sudo ln -sfn "$HOME/.opencode/bin/opencode" /usr/local/bin/opencode
}

install_tmuxai() {
  if command -v tmuxai >/dev/null 2>&1; then
    step "tmuxai (already installed)"
  else
    step "tmuxai -> installing"
    if ! curl -fsSL https://get.tmuxai.dev | bash; then
      curl -fL "https://github.com/alvinunreal/tmuxai/releases/latest/download/tmuxai_Linux_amd64.tar.gz" \
        | sudo tar xz -C /usr/local/bin --strip-components=0 tmuxai
    fi
  fi
}

install_ollama() {
  if command -v ollama >/dev/null 2>&1; then
    step "ollama (already installed)"
  else
    step "ollama -> installing"
    if ! curl -fsSL https://ollama.com/install.sh | sh; then
      curl -fL "https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64" \
        -o /tmp/ollama
      sudo install -o root -g root -m 755 /tmp/ollama /usr/local/bin/ollama
      rm -f /tmp/ollama
    fi
  fi

  if ollama list 2>/dev/null | grep -q 'qwen3:8b'; then
    step "qwen3:8b (already pulled)"
  else
    step "qwen3:8b -> pulling"
    ollama pull qwen3:8b
    printf 'FROM qwen3:8b\nPARAMETER num_ctx 16384\n' > /tmp/Modelfile-qwen3-16k
    ollama create qwen3:8b-16k -f /tmp/Modelfile-qwen3-16k
  fi
}

install_vagrant() {
  if dpkg -s vagrant >/dev/null 2>&1; then
    step "vagrant (already installed)"
  else
    local codename
    codename="$(lsb_release -cs 2>/dev/null || true)"
    if [ -z "$codename" ] || [ "$codename" = "sid" ] || [ "$codename" = "n/a" ]; then
      step "vagrant -> codename '$codename' not supported by HashiCorp, using 'trixie'"
      codename="trixie"
    fi

    if [ ! -f /etc/apt/sources.list.d/hashicorp.list ]; then
      step "vagrant -> adding HashiCorp repo ($codename)"
      curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $codename main" \
        | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
    fi

    step "vagrant -> installing"
    sudo apt update && sudo apt install -y vagrant
    RESTART_NEEDED=1
  fi

  if command -v vagrant >/dev/null 2>&1 && vagrant plugin list | grep -qi virtualbox_wsl2; then
    step "vagrant plugin virtualbox_WSL2 (already installed)"
  elif command -v vagrant >/dev/null 2>&1; then
    step "vagrant plugin virtualbox_WSL2 -> installing"
    vagrant plugin install virtualbox_WSL2
    RESTART_NEEDED=1
  fi
}

install_tmux_plugins() {
  if [ -d "$HOME/.tmux/plugins/tpm" ]; then
    step "tmux plugins (already installed)"
  else
    step "tmux plugins -> cloning tpm"
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    "$HOME/.tmux/plugins/tpm/bin/install_plugins"
  fi
}

install_dotfiles() {
  step "dotfiles -> ~/.tmux.conf"
  ln -sfn "$BASE/dotfiles/tmux.conf" "$HOME/.tmux.conf"
  step "dotfiles -> ~/.bashrc"
  ln -sfn "$BASE/dotfiles/bashrc" "$HOME/.bashrc"
  step "dotfiles -> ~/.bash_aliases"
  ln -sfn "$BASE/dotfiles/bash_aliases" "$HOME/.bash_aliases"
  step "dotfiles -> ~/.config/opencode/opencode.jsonc"
  mkdir -p "$HOME/.config/opencode"
  ln -sfn "$BASE/dotfiles/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"
  step "dotfiles -> ~/.config/tmuxai/config.yaml"
  mkdir -p "$HOME/.config/tmuxai"
  ln -sfn "$BASE/dotfiles/tmuxai.yaml" "$HOME/.config/tmuxai/config.yaml"
  step "dotfiles -> ~/.config/fastfetch/config.jsonc"
  mkdir -p "$HOME/.config/fastfetch"
  ln -sfn "$BASE/dotfiles/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
  step "dotfiles -> ~/.config/fastfetch/logo.png"
  ln -sfn "$BASE/dotfiles/logo.png" "$HOME/.config/fastfetch/logo.png"
  step "dotfiles -> ~/.config/fastfetch/logo.txt (rendering)"
  chafa --size 60x30 --symbols block+border+space-wide-inverted \
    "$HOME/.config/fastfetch/logo.png" > "$HOME/.config/fastfetch/logo.txt"
  install_wslconfig
}

install_wslconfig() {
  if ! command -v cmd.exe >/dev/null 2>&1 || ! command -v wslpath >/dev/null 2>&1; then
    step "wslconfig -> not running on WSL, skipping"
    return
  fi

  local win_home win_config
  win_home="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
  if [ -z "$win_home" ]; then
    step "wslconfig -> could not detect Windows profile, skipping"
    return
  fi

  win_config="$(wslpath -u "$win_home")/.wslconfig"
  if [ ! -d "$(dirname "$win_config")" ]; then
    step "wslconfig -> Windows profile not reachable, skipping"
    return
  fi

  if [ -f "$win_config" ]; then
    if cmp -s "$BASE/dotfiles/wslconfig" "$win_config"; then
      step "wslconfig (already in sync)"
    else
      step "wslconfig -> updating"
      cp "$BASE/dotfiles/wslconfig" "$win_config"
      RESTART_NEEDED=1
    fi
  else
    step "wslconfig -> installing"
    cp "$BASE/dotfiles/wslconfig" "$win_config"
    RESTART_NEEDED=1
  fi
}

mount_data_dir() {
  if mountpoint -q "$HOME/projects"; then
    step "mount data (already mounted)"
  else
    step "mount data -> creating $HOME/projects"
    mkdir -p "$HOME/projects"

    local uid gid
    uid="$(id -u)"
    gid="$(id -g)"
    step "mount data -> C:\\data\\projects -> $HOME/projects (uid=$uid, gid=$gid)"
    sudo mount -t drvfs -o "defaults,metadata,uid=$uid,gid=$gid" 'C:\data\projects' "$HOME/projects"
    sleep 2
  fi

  if ! grep -Fq 'C:\data\projects' /etc/fstab 2>/dev/null; then
    local uid gid
    uid="$(id -u)"
    gid="$(id -g)"
    step "mount data -> adding to /etc/fstab"
    echo "C:\\data\\projects $HOME/projects drvfs defaults,metadata,uid=$uid,gid=$gid 0 0" | sudo tee -a /etc/fstab
  fi
}

install_ssh() {
  local src="$HOME/projects/infra/wsl_ssh_key"
  if [ ! -f "$src/id_ed25519" ]; then
    step "ssh -> source key not found, skipping"
    return
  fi
  step "ssh -> copying keys"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  cp "$src/id_ed25519" "$HOME/.ssh/"
  chmod 600 "$HOME/.ssh/id_ed25519"
  cp "$src/id_ed25519.pub" "$HOME/.ssh/"
  chmod 644 "$HOME/.ssh/id_ed25519.pub"
}

configure_timezone() {
  local tz="America/Argentina/Buenos_Aires"
  if [ "$(timedatectl show -p Timezone --value 2>/dev/null)" = "$tz" ]; then
    step "timezone (already $tz)"
  else
    step "timezone -> setting to $tz"
    sudo timedatectl set-timezone "$tz" \
      || sudo ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime
  fi
}

configure_git() {
  if [ -n "$(git config --global user.name)" ] && [ -n "$(git config --global user.email)" ]; then
    step "git (already configured)"
  else
    step "git -> setting identity"
    git config --global user.name "c-lech"
    git config --global user.email "126396070+c-lech@users.noreply.github.com"
  fi
}

main() {
  RESTART_NEEDED=0

  configure_timezone
  install_packages
  install_fastfetch
  install_opencode
  install_tmuxai
  install_ollama
  install_vagrant
  install_dotfiles
  install_tmux_plugins
  configure_git
  mount_data_dir
  install_ssh

  section "Setup complete"
  if [ "$RESTART_NEEDED" = 1 ]; then
    echo "  Run 'wsl --shutdown' in PowerShell and reopen to apply changes."
  fi
}

main "$@"
