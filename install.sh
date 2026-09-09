#!/bin/bash

set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.install-logs"

C_OK=''
C_SKIP=''
C_FAIL=''
C_GRP=''
C_SECT=''
C_WHITE=''
RESET=''
if [ -t 1 ]; then
  C_OK=$'\033[32m'
  C_SKIP=$'\033[33m'
  C_FAIL=$'\033[31m'
  C_GRP=$'\033[1;36m'
  C_SECT=$'\033[1;95m'
  C_WHITE=$'\033[1;37m'
  RESET=$'\033[0m'
fi

VERBOSE=0

declare -A STATUS NOTE IN_ORDER GROUP
ORDER=()

step() {
  :
}

record() {
  local key="$1" class="$2" note="$3"
  STATUS["$key"]="$class"
  NOTE["$key"]="$note"
  if [ -z "${IN_ORDER[$key]+x}" ]; then
    IN_ORDER["$key"]=1
    ORDER+=("$key")
  fi
}

publish() {
  local key="$1"
  local anyfail=0 anyok=0 n=0 k
  for k in "${ORDER[@]}"; do
    if [ "$k" != "$key" ] && [[ "$k" == "$key:"* ]]; then
      n=1
      case "${STATUS[$k]}" in
        fail) anyfail=1;;
        ok)   anyok=1;;
      esac
      [ "$anyfail" = 1 ] && break
    fi
  done
  if [ "$n" = 0 ]; then
    return 0
  fi
  GROUP["$key"]=1
  if [ "$anyfail" = 1 ]; then
    STATUS["$key"]=fail
    NOTE["$key"]="some failed"
  elif [ "$anyok" = 1 ]; then
    STATUS["$key"]=ok
    NOTE["$key"]=""
  else
    STATUS["$key"]=skip
    NOTE["$key"]=""
  fi
}

get_version() {
  "$@" --version 2>/dev/null | head -1
}

log_tail() {
  if [ "$VERBOSE" = 1 ]; then
    local f="$LOG_DIR/$1"
    echo "  ! last output of $f:"
    tail -n 20 "$f" 2>/dev/null | sed 's/^/    /'
  fi
}


apt_update() {
  step "apt update"
  if ! sudo apt update >> "$LOG_DIR/apt-update.log" 2>&1; then
    log_tail apt-update.log
    return 1
  fi
}

apt_key() {
  local g="$1" p="$2"
  if [ "$p" = "zstd" ]; then
    echo "tools:ollama:server:zstd"
  else
    echo "apt:$g:$p"
  fi
}

install_packages() {
  step "checking packages"
  local packages=(
    # CPU
    "CPU|btop" "CPU|htop" "CPU|glances"
    # Disk
    "Disk|tree" "Disk|ncdu" "Disk|iotop" "Disk|sysstat"
    # Networking
    "Networking|mtr" "Networking|nmap" "Networking|traceroute" "Networking|dnsutils"
    "Networking|whois" "Networking|telnet" "Networking|iftop" "Networking|net-tools"
    "Networking|snmp" "Networking|socat"
    # Hardware
    "Hardware|lm-sensors" "Hardware|smartmontools" "Hardware|nvtop"
    # Remote
    "Remote|ansible" "Remote|sshpass"
    # Files
    "Files|fzf" "Files|mc"
    # Parse
    "Parse|jq" "Parse|yq"
    # Misc
    "Misc|figlet" "Misc|cmatrix"
    # Python pkg mgrs
    "Python pkg mgrs|python3-pip" "Python pkg mgrs|pipx"
    # Cargo deps
    "Cargo deps|pkg-config" "Cargo deps|libfontconfig1-dev" "Cargo deps|libfreetype-dev"
    "Cargo deps|libxcb-composite0-dev" "Cargo deps|libharfbuzz-dev" "Cargo deps|libexpat1-dev"
    # Cliamp deps
    "Cliamp deps|libasound2-plugins" "Cliamp deps|pulseaudio-utils" "Cliamp deps|ffmpeg"
    # Fastfetch util
    "Fastfetch util|chafa"
    # TMUX integration
    "TMUX integration|wl-clipboard"
    # Ollama deps
    # required by ollama server installation
    "Ollama deps|zstd"
  )

  local entry group pkg to_install=() apt_pkgs=()
  for entry in "${packages[@]}"; do
    group="${entry%%|*}"
    pkg="${entry#*|}"
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      if [ "$pkg" = "ansible" ]; then
        record "$(apt_key "$group" "$pkg")" skip "already installed ${C_SECT}($(ansible --version 2>/dev/null | head -1 | awk '{print $3}' | tr -d ']'))${RESET}"
      else
        record "$(apt_key "$group" "$pkg")" skip "already installed"
      fi
    else
      to_install+=("$entry")
    fi
  done

  if [ "${#to_install[@]}" -eq 0 ]; then
    step "no packages to install"
    return 0
  fi

  if ! apt_update; then
    for entry in "${to_install[@]}"; do
      record "$(apt_key "${entry%%|*}" "${entry#*|}")" fail "failed (apt update)"
    done
    return 0
  fi

  for entry in "${to_install[@]}"; do
    apt_pkgs+=("${entry#*|}")
  done

  step "apt install ${#apt_pkgs[@]} packages (single run)"
  if sudo apt install -y "${apt_pkgs[@]}" >> "$LOG_DIR/apt-install.log" 2>&1; then
    for entry in "${to_install[@]}"; do
      group="${entry%%|*}"
      pkg="${entry#*|}"
      if [ "$pkg" = "ansible" ]; then
        record "$(apt_key "$group" "$pkg")" ok "installed ${C_SECT}($(ansible --version 2>/dev/null | head -1 | awk '{print $3}' | tr -d ']'))${RESET}"
      else
        record "$(apt_key "$group" "$pkg")" ok "installed"
      fi
    done
    return 0
  fi

  step "batch install failed, retrying individually"
  log_tail apt-install.log
  for entry in "${to_install[@]}"; do
    group="${entry%%|*}"
    pkg="${entry#*|}"
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      if [ "$pkg" = "ansible" ]; then
        record "$(apt_key "$group" "$pkg")" ok "installed ${C_SECT}($(ansible --version 2>/dev/null | head -1 | awk '{print $3}' | tr -d ']'))${RESET}"
      else
        record "$(apt_key "$group" "$pkg")" ok "installed"
      fi
    elif sudo apt install -y "$pkg" >> "$LOG_DIR/apt-$pkg.log" 2>&1; then
      if [ "$pkg" = "ansible" ]; then
        record "$(apt_key "$group" "$pkg")" ok "installed ${C_SECT}($(ansible --version 2>/dev/null | head -1 | awk '{print $3}' | tr -d ']'))${RESET}"
      else
        record "$(apt_key "$group" "$pkg")" ok "installed"
      fi
    else
      record "$(apt_key "$group" "$pkg")" fail "failed"
      log_tail "apt-$pkg.log"
    fi
  done
}

install_fastfetch() {
  local log="$LOG_DIR/fastfetch.log"
  if command -v fastfetch >/dev/null 2>&1; then
    record "tools:fastfetch" skip "already installed"
    return 0
  fi
  step "fastfetch -> adding PPA"
  if ! sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch >> "$log" 2>&1; then
    log_tail fastfetch.log
    record "tools:fastfetch" fail "failed (PPA)"
    return 1
  fi
  if ! apt_update; then
    record "tools:fastfetch" fail "failed (apt update)"
    return 1
  fi
  step "fastfetch -> installing"
  if ! sudo apt install -y fastfetch >> "$log" 2>&1; then
    log_tail fastfetch.log
    record "tools:fastfetch" fail "failed"
    return 1
  fi
  record "tools:fastfetch" ok "installed"
}

install_opencode() {
  local log="$LOG_DIR/opencode.log"
  record "tools:agent" skip "pending"
  if [ -x "$HOME/.opencode/bin/opencode" ]; then
    local ver
    ver="$("$HOME/.opencode/bin/opencode" --version 2>/dev/null | head -1)"
    if [ "$(readlink /usr/local/bin/opencode 2>/dev/null)" = "$HOME/.opencode/bin/opencode" ]; then
      record "tools:agent:opencode" skip "already installed ${C_SECT}($ver)${RESET}"
    else
      step "opencode -> relinking binary"
      sudo ln -sfn "$HOME/.opencode/bin/opencode" /usr/local/bin/opencode
      record "tools:agent:opencode" ok "relinked ${C_SECT}($ver)${RESET}"
    fi
    publish "tools:agent"
    return 0
  fi
  step "opencode -> installing"
  if ! curl -fsSL https://opencode.ai/install 2>>"$log" | bash >> "$log" 2>&1; then
    log_tail opencode.log
    step "opencode -> install script failed, trying tarball"
    mkdir -p "$HOME/.opencode/bin"
    if ! curl -fsL "https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-x64.tar.gz" \
        | tar xz -C "$HOME/.opencode/bin" >> "$log" 2>&1; then
      log_tail opencode.log
      record "tools:agent:opencode" fail "failed"
      publish "tools:agent"
      return 1
    fi
  fi
  step "opencode -> linking binary"
  sudo ln -sfn "$HOME/.opencode/bin/opencode" /usr/local/bin/opencode
  record "tools:agent:opencode" ok "installed ${C_SECT}($("$HOME/.opencode/bin/opencode" --version 2>/dev/null | head -1))${RESET}"
  publish "tools:agent"
}

install_tmuxai() {
  local log="$LOG_DIR/tmuxai.log"
  if command -v tmuxai >/dev/null 2>&1; then
    record "tools:tmuxai" skip "already installed"
    return 0
  fi
  step "tmuxai -> installing"
  if ! curl -fsSL https://get.tmuxai.dev 2>>"$log" | bash >> "$log" 2>&1; then
    log_tail tmuxai.log
    step "tmuxai -> install script failed, trying tarball"
    if ! curl -fsL "https://github.com/alvinunreal/tmuxai/releases/latest/download/tmuxai_Linux_amd64.tar.gz" \
        | sudo tar xz -C /usr/local/bin --strip-components=0 tmuxai >> "$log" 2>&1; then
      log_tail tmuxai.log
      record "tools:tmuxai" fail "failed"
      return 1
    fi
  fi
  record "tools:tmuxai" ok "installed"
}

model_present() {
  ollama list 2>/dev/null | awk -v m="$1" '$1==m {found=1} END {exit !found}'
}

install_ollama() {
  local log="$LOG_DIR/ollama.log"
  record "tools:ollama" skip "pending"

  if command -v ollama >/dev/null 2>&1; then
    local ver
    ver="$(get_version ollama | awk '{print $NF}')"
    record "tools:ollama:server" skip "already installed ${C_SECT}($ver)${RESET}"
  else
    step "ollama -> installing"
    if ! curl -fsSL https://ollama.com/install.sh 2>>"$log" | sh >> "$log" 2>&1; then
      log_tail ollama.log
      step "ollama -> install script failed, trying binary"
      if ! curl -fsL "https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64" \
            -o /tmp/ollama >> "$log" 2>&1 \
          || ! sudo install -o root -g root -m 755 /tmp/ollama /usr/local/bin/ollama >> "$log" 2>&1; then
        rm -f /tmp/ollama
        log_tail ollama.log
        record "tools:ollama:server" fail "failed"
        publish "tools:ollama"
        return 1
      fi
      rm -f /tmp/ollama
    fi
    record "tools:ollama:server" ok "installed ${C_SECT}($(get_version ollama | awk '{print $NF}'))${RESET}"
  fi

  if model_present "qwen3:8b"; then
    record "tools:ollama:qwen3:8b" skip "already pulled"
  else
    step "ollama -> pulling qwen3:8b"
    if ollama pull qwen3:8b >> "$log" 2>&1; then
      record "tools:ollama:qwen3:8b" ok "pulled"
    else
      record "tools:ollama:qwen3:8b" fail "pull failed"
    fi
  fi

  if model_present "qwen3:8b-16k"; then
    record "tools:ollama:qwen3:8b-16k" skip "already created"
  else
    step "ollama -> creating qwen3:8b-16k"
    printf 'FROM qwen3:8b\nPARAMETER num_ctx 16384\n' > /tmp/Modelfile-qwen3-16k
    if ollama create qwen3:8b-16k -f /tmp/Modelfile-qwen3-16k >> "$log" 2>&1; then
      record "tools:ollama:qwen3:8b-16k" ok "created"
    else
      record "tools:ollama:qwen3:8b-16k" fail "create failed"
    fi
  fi
  publish "tools:ollama"
}

install_vagrant() {
  local log="$LOG_DIR/vagrant.log"

  if dpkg -s vagrant >/dev/null 2>&1; then
    local ver
    ver="$(get_version vagrant | awk '{print $2}')"
    record "tools:vagrant" skip "already installed ${C_SECT}($ver)${RESET}"
  else
    local codename
    codename="$(lsb_release -cs 2>/dev/null || true)"
    if [ -z "$codename" ] || [ "$codename" = "sid" ] || [ "$codename" = "n/a" ]; then
      step "vagrant -> codename '$codename' not supported by HashiCorp, using 'trixie'"
      codename="trixie"
    fi

    if [ ! -f /etc/apt/sources.list.d/hashicorp.list ]; then
      step "vagrant -> adding HashiCorp repo ($codename)"
      if ! curl -fsSL https://apt.releases.hashicorp.com/gpg \
          | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg >> "$log" 2>&1; then
        log_tail vagrant.log
        record "tools:vagrant" fail "failed (repo key)"
        return 1
      fi
      echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $codename main" \
        | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
    fi

    if ! apt_update; then
      record "tools:vagrant" fail "failed (apt update)"
      return 1
    fi
    step "vagrant -> installing"
    if ! sudo apt install -y vagrant >> "$log" 2>&1; then
      log_tail vagrant.log
      record "tools:vagrant" fail "failed"
      return 1
    fi
    record "tools:vagrant" ok "installed ${C_SECT}($(get_version vagrant | awk '{print $2}'))${RESET}"
    VAGRANT_RESTART_NEEDED=1
  fi

  if ! command -v vagrant >/dev/null 2>&1; then
    record "tools:vagrant:virtualbox_WSL2 plugin" fail "not installed (vagrant missing)"
    return 1
  fi

  if vagrant plugin list | grep -qi virtualbox_wsl2; then
    local ver
    ver="$(vagrant plugin list | grep -i virtualbox_wsl2 | grep -oP '\(\K[^,]+')"
    record "tools:vagrant:virtualbox_WSL2 plugin" skip "already installed ${C_SECT}($ver)${RESET}"
  else
    step "vagrant plugin virtualbox_WSL2 -> installing"
    if vagrant plugin install virtualbox_WSL2 >> "$log" 2>&1; then
      record "tools:vagrant:virtualbox_WSL2 plugin" ok "installed ${C_SECT}($(vagrant plugin list | grep -i virtualbox_wsl2 | grep -oP '\(\K[^,]+'))${RESET}"
      VAGRANT_RESTART_NEEDED=1
    else
      log_tail vagrant.log
      record "tools:vagrant:virtualbox_WSL2 plugin" fail "failed"
    fi
  fi
}

install_cliamp() {
  local log="$LOG_DIR/cliamp.log"
  if command -v cliamp >/dev/null 2>&1; then
    record "tools:cliamp" skip "already installed"
    return 0
  fi
  step "cliamp -> installing"
  if ! curl -fsSL https://cliamp.stream/install.sh 2>>"$log" | sh >> "$log" 2>&1; then
    log_tail cliamp.log
    record "tools:cliamp" fail "failed"
    return 1
  fi
  record "tools:cliamp" ok "installed"
}

install_golazo() {
  local log="$LOG_DIR/golazo.log"
  if command -v golazo >/dev/null 2>&1; then
    record "tools:golazo" skip "already installed"
    return 0
  fi
  step "golazo -> installing"
  if ! curl -fsSL https://raw.githubusercontent.com/0xjuanma/golazo/main/scripts/install.sh 2>>"$log" | bash >> "$log" 2>&1; then
    log_tail golazo.log
    record "tools:golazo" fail "failed"
    return 1
  fi
  record "tools:golazo" ok "installed"
}

install_tdfiglet() {
  local log="$LOG_DIR/tdfiglet.log"
  if command -v tdfiglet >/dev/null 2>&1; then
    record "tools:tdfiglet" skip "already installed"
    return 0
  fi

  local build_dir="/tmp/tdfiglet"
  rm -rf "$build_dir"
  step "tdfiglet -> cloning repo"
  if ! git clone https://github.com/tat3r/tdfiglet.git "$build_dir" >> "$log" 2>&1; then
    log_tail tdfiglet.log
    record "tools:tdfiglet" fail "failed (clone)"
    rm -rf "$build_dir"
    return 1
  fi

  step "tdfiglet -> building"
  if ! make -C "$build_dir" >> "$log" 2>&1; then
    log_tail tdfiglet.log
    record "tools:tdfiglet" fail "failed (make)"
    rm -rf "$build_dir"
    return 1
  fi

  step "tdfiglet -> installing binary + fonts"
  if ! sudo make -C "$build_dir" install >> "$log" 2>&1; then
    log_tail tdfiglet.log
    record "tools:tdfiglet" fail "failed (make install)"
    rm -rf "$build_dir"
    return 1
  fi

  record "tools:tdfiglet" ok "installed"
  rm -rf "$build_dir"
}

install_tte() {
  local log="$LOG_DIR/tte.log"
  if command -v tte >/dev/null 2>&1; then
    record "tools:tte" skip "already installed"
    return 0
  fi
  step "tte -> installing terminaltexteffects"
  if ! pipx install terminaltexteffects >> "$log" 2>&1; then
    log_tail tte.log
    record "tools:tte" fail "failed"
    return 1
  fi
  record "tools:tte" ok "installed"
}

install_rust() {
  local log="$LOG_DIR/rust.log"
  if command -v cargo >/dev/null 2>&1; then
    local ver
    ver="$(cargo --version 2>/dev/null | awk '{print $2}')"
    record "tools:rust" skip "already installed ${C_SECT}($ver)${RESET}"
  else
    step "rust -> installing via rustup"
    if ! curl -sSf https://sh.rustup.rs 2>>"$log" | sh -s -- -y --profile minimal --default-toolchain stable >> "$log" 2>&1; then
      log_tail rust.log
      record "tools:rust" fail "failed (rustup)"
      return 1
    fi
    [ -s "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
    record "tools:rust" ok "installed ${C_SECT}($(cargo --version 2>/dev/null | awk '{print $2}'))${RESET}"
  fi
  [ -s "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
  command -v cargo >/dev/null 2>&1 || record "tools:rust" fail "cargo not on PATH after install"
}

install_silicon() {
  local log="$LOG_DIR/silicon.log"
  if command -v silicon >/dev/null 2>&1; then
    record "tools:silicon" skip "already installed"
    return 0
  fi
  [ -s "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
  if ! command -v cargo >/dev/null 2>&1; then
    record "tools:silicon" fail "cargo missing"
    return 1
  fi
  step "silicon -> cargo install (this may take a while)"
  if ! cargo install silicon >> "$log" 2>&1; then
    log_tail silicon.log
    record "tools:silicon" fail "failed"
    return 1
  fi
  record "tools:silicon" ok "installed"
}

install_node() {
  local log="$LOG_DIR/node.log"

  # nvm (installed first, recorded after node)
  local nvm_status="skip" nvm_note=""
  if [ -s "$HOME/.nvm/nvm.sh" ]; then
    export NVM_DIR="$HOME/.nvm"
    . "$NVM_DIR/nvm.sh"
    nvm_note="already installed ${C_SECT}($(nvm --version))${RESET}"
  else
    step "node -> installing nvm"
    if ! curl -so- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh \
        | bash >> "$log" 2>&1; then
      log_tail node.log
      record "tools:nvm" fail "failed"
      return 1
    fi
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm_status="ok"
    nvm_note="installed ${C_SECT}($(nvm --version))${RESET}"
  fi

  # node LTS
  if command -v node >/dev/null 2>&1; then
    record "tools:node" skip "already installed ${C_SECT}($(node --version))${RESET}"
  else
    step "node -> installing LTS"
    if ! nvm install --lts >> "$log" 2>&1; then
      log_tail node.log
      record "tools:node" fail "failed"
      return 1
    fi
    record "tools:node" ok "installed ${C_SECT}($(node --version))${RESET}"
  fi

  # nvm (recorded after node)
  record "tools:nvm" "$nvm_status" "$nvm_note"

  # cfonts (global)
  if npm ls -g cfonts >/dev/null 2>&1; then
    record "tools:cfonts" skip "already installed"
  else
    step "node -> installing cfonts"
    if ! npm i -g cfonts >> "$log" 2>&1; then
      log_tail node.log
      record "tools:cfonts" fail "failed"
      return 1
    fi
    record "tools:cfonts" ok "installed"
  fi
}

install_tmux_plugins() {
  local plugins_dir="$HOME/.tmux/plugins"
  local log="$LOG_DIR/tmux-plugins.log"

  if [ ! -d "$plugins_dir/tpm" ]; then
    step "tmux plugins -> cloning tpm"
    if ! git clone https://github.com/tmux-plugins/tpm "$plugins_dir/tpm" >> "$log" 2>&1; then
      log_tail tmux-plugins.log
      record "tools:tmux-plugins" fail "failed (tpm clone)"
      return 1
    fi
    step "tmux plugins -> installing plugins"
    if "$plugins_dir/tpm/bin/install_plugins" >> "$log" 2>&1; then
      record "tools:tmux-plugins" ok "installed"
    else
      log_tail tmux-plugins.log
      record "tools:tmux-plugins" fail "failed"
    fi
    return 0
  fi

  local missing=0 line
  while IFS= read -r line; do
    line="${line#*@plugin}"
    line="${line//[[:space:]]/}"
    line="${line#[\'\"]}"
    line="${line%[\'\"]}"
    [ -n "$line" ] || continue
    [ "$line" != "tmux-plugins/tpm" ] || continue
    local name="${line##*/}"
    if [ ! -d "$plugins_dir/$name" ]; then
      missing=1
    fi
  done < <(grep "@plugin" "$HOME/.tmux.conf")

  if [ "$missing" = 1 ]; then
    step "tmux plugins -> repairing missing plugins"
    if "$plugins_dir/tpm/bin/install_plugins" >> "$log" 2>&1; then
      record "tools:tmux-plugins" ok "repaired"
    else
      log_tail tmux-plugins.log
      record "tools:tmux-plugins" fail "reinstall failed"
    fi
  else
    record "tools:tmux-plugins" skip "already installed"
  fi
}

install_dotfiles() {
  step "dotfiles -> checking"
  local entries=(
    "$HOME/.tmux.conf|$BASE/dotfiles/tmux.conf|link"
    "$HOME/.bashrc|$BASE/dotfiles/bashrc|link"
    "$HOME/.bash_aliases|$BASE/dotfiles/bash_aliases|link"
    "$HOME/.asoundrc|$BASE/dotfiles/asoundrc|link"
    "$HOME/.config/opencode/opencode.jsonc|$BASE/dotfiles/opencode.jsonc|link"
    "$HOME/.config/tmuxai/config.yaml|$BASE/dotfiles/tmuxai.yaml|link"
    "$HOME/.config/golazo/settings.yaml|$BASE/dotfiles/golazo-settings.yaml|link"
    "$HOME/.config/cliamp/radios.toml|$BASE/dotfiles/cliamp-radios.toml|link"
    "$HOME/.config/cliamp/config.toml|$BASE/dotfiles/cliamp.toml|copy"
    "$HOME/.config/fastfetch/config.jsonc|$BASE/dotfiles/config.jsonc|link"
    "$HOME/.config/fastfetch/logo.png|$BASE/dotfiles/logo.png|link"
  )

  record "system:link dot files" skip "pending"

  local entry dest rest src kind
  for entry in "${entries[@]}"; do
    dest="${entry%%|*}"
    rest="${entry#*|}"
    src="${rest%%|*}"
    kind="${rest#*|}"
    if [ "$kind" = "copy" ]; then
      if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
        record "system:link dot files:$dest" skip "already copied"
      else
        step "dotfiles -> $dest (copy)"
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
        record "system:link dot files:$dest" ok "copied"
      fi
    else
      if [ "$(readlink "$dest" 2>/dev/null)" = "$src" ]; then
        record "system:link dot files:$dest" skip "already linked"
      else
        step "dotfiles -> $dest"
        mkdir -p "$(dirname "$dest")"
        ln -sfn "$src" "$dest"
        record "system:link dot files:$dest" ok "linked"
      fi
    fi
  done

  if [ -f "$HOME/.config/fastfetch/logo.txt" ]; then
    record "system:link dot files:$HOME/.config/fastfetch/logo.txt" skip "already rendered"
  else
    step "dotfiles -> rendering fastfetch logo"
    if ! chafa --size 60x30 --symbols block+border+space-wide-inverted \
          "$HOME/.config/fastfetch/logo.png" > "$HOME/.config/fastfetch/logo.txt" 2> "$LOG_DIR/dotfiles.log"; then
      log_tail dotfiles.log
      record "system:link dot files:$HOME/.config/fastfetch/logo.txt" fail "failed (logo render)"
      publish "system:link dot files"
      return 1
    fi
    record "system:link dot files:$HOME/.config/fastfetch/logo.txt" ok "rendered"
  fi

  publish "system:link dot files"
}

install_wslconfig() {
  if ! command -v cmd.exe >/dev/null 2>&1 || ! command -v wslpath >/dev/null 2>&1; then
    record "system:wsl config (on host)" skip "not on WSL"
    return 0
  fi

  local win_home win_config
  win_home="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
  if [ -z "$win_home" ]; then
    record "system:wsl config (on host)" skip "no Windows profile"
    return 0
  fi

  win_config="$(wslpath -u "$win_home")/.wslconfig"
  if [ ! -d "$(dirname "$win_config")" ]; then
    record "system:wsl config (on host)" skip "Windows profile unreachable"
    return 0
  fi

  record "system:wsl config (on host)" skip "pending"

  if [ "$(readlink /etc/wsl.conf 2>/dev/null)" = "$BASE/dotfiles/wsl.conf" ]; then
    record "system:wsl config (on host):/etc/wsl.conf" skip "already linked"
  else
    step "wsl.conf -> linking"
    sudo ln -sfn "$BASE/dotfiles/wsl.conf" /etc/wsl.conf
    record "system:wsl config (on host):/etc/wsl.conf" ok "linked"
  fi

  if [ -f "$win_config" ]; then
    if cmp -s "$BASE/dotfiles/wslconfig" "$win_config"; then
      record "system:wsl config (on host):$win_config" skip "already copied"
    else
      step "wslconfig -> updating"
      cp "$BASE/dotfiles/wslconfig" "$win_config"
      record "system:wsl config (on host):$win_config" ok "copied"
    fi
  else
    step "wslconfig -> installing"
    cp "$BASE/dotfiles/wslconfig" "$win_config"
    record "system:wsl config (on host):$win_config" ok "copied"
  fi

  publish "system:wsl config (on host)"
}

mount_data_dir() {
  record "system:mount shared data" skip "pending"

  if ! mountpoint -q "$HOME/projects"; then
    step "mount data -> creating $HOME/projects"
    mkdir -p "$HOME/projects"

    local uid gid
    uid="$(id -u)"
    gid="$(id -g)"
    step "mount data -> C:\\data\\projects -> $HOME/projects (uid=$uid, gid=$gid)"
    if ! sudo mount -t drvfs -o "defaults,metadata,uid=$uid,gid=$gid" \
          'C:\data\projects' "$HOME/projects" >> "$LOG_DIR/mount.log" 2>&1; then
      log_tail mount.log
      record "system:mount shared data:live mount (drvfs)" fail "mount failed"
      publish "system:mount shared data"
      return 1
    fi
    sleep 2
    record "system:mount shared data:live mount (drvfs)" ok "mounted"
  else
    record "system:mount shared data:live mount (drvfs)" skip "already mounted"
  fi

  if ! grep -Fq 'C:\data\projects' /etc/fstab 2>/dev/null; then
    local uid gid
    uid="$(id -u)"
    gid="$(id -g)"
    step "mount data -> adding to /etc/fstab"
    if echo "C:\\data\\projects $HOME/projects drvfs defaults,metadata,uid=$uid,gid=$gid 0 0" \
        | sudo tee -a /etc/fstab >> "$LOG_DIR/mount.log" 2>&1; then
      record "system:mount shared data:fstab entry" ok "added"
    else
      record "system:mount shared data:fstab entry" fail "failed"
    fi
  else
    record "system:mount shared data:fstab entry" skip "already added"
  fi

  publish "system:mount shared data"
}

install_ssh() {
  local src="$HOME/projects/infra/wsl_ssh_key"
  if [ ! -f "$src/id_ed25519" ]; then
    record "system:copy ssh keys" skip "no source key"
    return 0
  fi

  record "system:copy ssh keys" skip "pending"

  if [ -f "$HOME/.ssh/id_ed25519" ] && cmp -s "$src/id_ed25519" "$HOME/.ssh/id_ed25519"; then
    record "system:copy ssh keys:id_ed25519" skip "already copied"
  else
    step "ssh -> copying private key"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    cp "$src/id_ed25519" "$HOME/.ssh/"
    chmod 600 "$HOME/.ssh/id_ed25519"
    record "system:copy ssh keys:id_ed25519" ok "copied"
  fi

  if [ -f "$HOME/.ssh/id_ed25519.pub" ] && cmp -s "$src/id_ed25519.pub" "$HOME/.ssh/id_ed25519.pub"; then
    record "system:copy ssh keys:id_ed25519.pub" skip "already copied"
  else
    step "ssh -> copying public key"
    cp "$src/id_ed25519.pub" "$HOME/.ssh/"
    chmod 644 "$HOME/.ssh/id_ed25519.pub"
    record "system:copy ssh keys:id_ed25519.pub" ok "copied"
  fi

  publish "system:copy ssh keys"
}

configure_timezone() {
  local tz="America/Argentina/Buenos_Aires"
  local current
  current="$(timedatectl show -p Timezone --value 2>/dev/null)"
  if [ "$current" = "$tz" ]; then
    record "system:set time zone" skip "already configured ${C_SECT}($tz)${RESET}"
  else
    step "timezone -> setting to $tz"
    if ! sudo timedatectl set-timezone "$tz" \
        && ! sudo ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime; then
      record "system:set time zone" fail "failed"
      return 1
    fi
    record "system:set time zone" ok "configured ${C_SECT}($tz)${RESET}"
  fi
}

configure_git() {
  record "system:config git" skip "pending"

  if [ -n "$(git config --global user.name)" ] && [ -n "$(git config --global user.email)" ]; then
    step "git -> identity already set"
    record "system:config git:identity" skip "already set"
  else
    step "git -> setting identity"
    git config --global user.name "c-lech"
    git config --global user.email "126396070+c-lech@users.noreply.github.com"
    record "system:config git:identity" ok "set"
  fi

  if [ "$(git config --global credential.helper)" != "store" ]; then
    step "git -> enabling credential.helper store"
    git config --global credential.helper store
    record "system:config git:credential.helper store" ok "enabled"
  else
    record "system:config git:credential.helper store" skip "already enabled"
  fi

  local src="$HOME/projects/infra/git_credentials/git-credentials"
  if [ -f "$src" ]; then
    if [ -f "$HOME/.git-credentials" ]; then
      record "system:config git:git-credentials" skip "already copied"
    else
      step "git -> copying credentials"
      cp "$src" "$HOME/.git-credentials"
      chmod 600 "$HOME/.git-credentials"
      record "system:config git:git-credentials" ok "copied"
    fi
  else
    record "system:config git:git-credentials" skip "no source credentials"
  fi

  publish "system:config git"
}

run_step() {
  local key="$1" name="$2"
  shift 2

  set +e
  "$@"
  local rc=$?
  set -e

  if [ "$rc" -ne 0 ] && [ -z "${STATUS[$key]+x}" ]; then
    record "$key" fail "failed (exit $rc)"
  fi

  [ "$VERBOSE" = 1 ] && printf "  %s\n" "$name"

  return 0
}

report() {
  echo ""
  local n_ok=0 n_skip=0 n_fail=0

  declare -A P=(
    ["python"]="apt:Python pkg mgrs"
    ["nodejs"]="tools:nvm;tools:node"
    ["rust"]="tools:rust;apt:Cargo deps"
    ["CPU"]="apt:CPU"
    ["disk"]="apt:Disk"
    ["networking"]="apt:Networking"
    ["hardware"]="apt:Hardware"
    ["remote"]="apt:Remote;tools:vagrant"
    ["files"]="apt:Files"
    ["parse"]="apt:Parse"
    ["render"]="tools:silicon"
    ["AI"]="tools:agent;tools:ollama"
    ["MISC"]="tools:golazo;tools:cliamp;apt:Misc:cmatrix;apt:Cliamp deps"
    ["tmux"]="tools:tmuxai;tools:tmux-plugins;apt:TMUX integration"
    ["fastfetch"]="tools:fastfetch;apt:Fastfetch util"
    ["ascii"]="tools:tdfiglet;tools:tte;tools:cfonts;apt:Misc:figlet"
    ["system"]="system"
  )
  local sections=(python nodejs rust CPU disk networking hardware remote files parse render AI tmux fastfetch ascii MISC system)

  local -A SUB_MEMBER=(
    [python]=dev [nodejs]=dev [rust]=dev
    [CPU]=mon [disk]=mon [networking]=mon [hardware]=mon
    [remote]=infra
    [files]=tools [parse]=tools [render]=tools
    [tmux]=looks [fastfetch]=looks [ascii]=looks
  )
  local -A SUB_FIRST=(
    [python]="DEV ENVIRONMENTS"
    [CPU]="MONITORING"
    [remote]="INFRA"
    [files]="TOOLS"
    [tmux]="TERMINAL & LOOKS"
  )

  local -A VPARENT=( ["apt:Cliamp deps"]="tools:cliamp" )

  local -a I_SEC I_NAME I_IND I_COL I_CLS I_LBL I_BKT I_GRP I_KEY I_PKEY
  for k in "${ORDER[@]}"; do
    local sec="" pref="" s plist p
    for s in "${sections[@]}"; do
      IFS=';' read -ra plist <<< "${P[$s]}"
      for p in "${plist[@]}"; do
        if [ "$k" = "$p" ] || [[ "$k" == "$p:"* ]]; then
          sec="$s"; pref="$p"; break 2
        fi
      done
    done
    if [ -z "$sec" ]; then
      sec="MISC"; pref="apt:Misc"
    fi
    local parent="" vp=""
    local a
    for a in "${ORDER[@]}"; do
      if [ "$a" != "$k" ] && [[ "$k" == "$a:"* ]] && [ "${#a}" -gt "${#parent}" ]; then
        parent="$a"
      fi
    done
    if [ -z "$parent" ]; then
      local vk t
      for vk in "${!VPARENT[@]}"; do
        if [[ "$k" == "$vk:"* ]]; then
          for t in "${ORDER[@]}"; do
            if [ "$t" = "${VPARENT[$vk]}" ]; then
              parent="$t"; vp="$vk"; break
            fi
          done
        fi
        [ -n "$parent" ] && break
      done
      unset vk t
    fi
    local name ind="    " bucket=0 gparent=""
    if [ -n "$parent" ]; then
      local g
      for g in "${ORDER[@]}"; do
        if [ "$g" != "$parent" ] && [ "$g" != "$k" ] && [[ "$parent" == "$g:"* ]] && [ "${#g}" -gt "${#gparent}" ]; then
          gparent="$g"
        fi
      done
      if [ -n "$vp" ]; then
        name="${k#"$vp:"}"
      else
        name="${k#"$parent:"}"
      fi
      if [ -n "$gparent" ]; then
        ind="        "
      else
        ind="      "
      fi
    else
      if [ "$k" = "$pref" ]; then
        name="${k##*:}"
      else
        name="${k#"$pref:"}"
      fi
    fi
    case "$k" in
      "system:config git")           name="configure git";;
      "system:wsl config (on host)") name="configure wsl";;
    esac
    [[ "$pref" == tools:* ]] && bucket=1
    if [ "$sec" = "system" ]; then
      if [ -n "$parent" ]; then
        ind="    "
      else
        ind="  "
      fi
    fi
    [[ "${SUB_MEMBER[$sec]+x}" = x ]] && ind="  $ind"
    local col=""
    case "$k" in
      "system:config git:git-credentials"|\
      "system:copy ssh keys:id_ed25519"|\
      "system:copy ssh keys:id_ed25519.pub") col="$C_FAIL";;
    esac
    case "$k" in
      "tools:ollama:server") name="ollama server";;
    esac
    if [ "$sec" = "AI" ]; then
      case "$k" in
        "tools:agent"|"tools:ollama")           col="$C_GRP";;
        "tools:agent:opencode"|"tools:ollama:server") col="$C_SECT";;
        *)                                        col="";;
      esac
    elif [ "$bucket" = 1 ] || [ "$sec" = "system" ]; then
      if [ "$bucket" = 1 ]; then
        [ -z "$col" ] && col="$C_SECT"
      else
        [ -z "$parent" ] && [ -z "$col" ] && col="$C_GRP"
      fi
    fi
    I_SEC+=( "$sec" ); I_NAME+=( "$name" ); I_IND+=( "$ind" ); I_COL+=( "$col" ); I_BKT+=( "$bucket" )
    I_CLS+=( "${STATUS[$k]}" ); I_LBL+=( "${NOTE[$k]}" )
    I_KEY+=( "$k" ); I_PKEY+=( "${parent:-}" )
    I_GRP+=( "$([[ -n "${GROUP[$k]+x}" ]] && echo 1 || echo 0)" )
  done

  local W=0 i
  for i in "${!I_SEC[@]}"; do
    local ln=$(( ${#I_IND[$i]} + ${#I_NAME[$i]} ))
    [ "$ln" -gt "$W" ] && W="$ln"
  done

  local has_tools=0
  for i in "${!I_SEC[@]}"; do
    if [ "${I_SEC[$i]}" != "system" ]; then
      has_tools=1
      break
    fi
  done
  if [ "$has_tools" = 1 ]; then
    echo "${C_SKIP}TOOLS${RESET}"
    echo ""
  fi

  local first=1
  for s in "${sections[@]}"; do
    local -a tid=() oid=()
    for i in "${!I_SEC[@]}"; do
      [ "${I_SEC[$i]}" = "$s" ] || continue
      if [ "${I_BKT[$i]}" = 1 ]; then
        tid+=( "$i" )
      else
        oid+=( "$i" )
      fi
    done
    [ "${#tid[@]}" -eq 0 ] && [ "${#oid[@]}" -eq 0 ] && continue
    local s_ind="  " skip_blank=0
    if [ "${SUB_FIRST[$s]+x}" = x ]; then
      if [ "$first" = 0 ]; then
        echo ""
      fi
      echo "  ${C_SKIP}${SUB_FIRST[$s]}${RESET}"
      echo ""
      first=0
      skip_blank=1
      s_ind="    "
    elif [ "${SUB_MEMBER[$s]+x}" = x ]; then
      s_ind="    "
    fi
    if [ "$first" = 0 ] && [ "$skip_blank" = 0 ]; then
      echo ""
    fi
    first=0
    if [ "$s" = "system" ]; then
      echo "${C_SKIP}SYSTEM${RESET}"
    elif [ "$s" = "AI" ]; then
      echo "  ${C_SKIP}AI${RESET}"
      echo ""
    elif [ "$s" = "MISC" ]; then
      echo "  ${C_SKIP}MISC${RESET}"
    else
      echo "${s_ind}${C_GRP}$s${RESET}"
    fi
    local -a ids=()
    if [ "$s" = "system" ]; then
      ids=( "${oid[@]}" "${tid[@]}" )
    else
      local -a all=() order=()
      for r in "${tid[@]}" "${oid[@]}"; do all+=( "$r" ); done
      if [ "$s" = "remote" ]; then
        order=( "${oid[@]}" "${tid[@]}" )
      else
        order=( "${tid[@]}" "${oid[@]}" )
      fi
      local -A seen=()
      local r j isp
      for r in "${order[@]}"; do
        [ -n "${I_PKEY[$r]}" ] && continue
        isp=0
        for j in "${all[@]}"; do
          [ "$j" = "$r" ] && continue
          [ "${I_PKEY[$j]}" = "${I_KEY[$r]}" ] && { isp=1; break; }
        done
        [ "$isp" = 1 ] && continue
        ids+=( "$r" ); seen[$r]=1
      done
      for r in "${order[@]}"; do
        [ -n "${I_PKEY[$r]}" ] && continue
        isp=0
        for j in "${all[@]}"; do
          [ "$j" = "$r" ] && continue
          [ "${I_PKEY[$j]}" = "${I_KEY[$r]}" ] && { isp=1; break; }
        done
        [ "$isp" = 0 ] && continue
        local -a st=()
        st+=( "$r" )
        while [ "${#st[@]}" -gt 0 ]; do
          local cur="${st[0]}"
          st=( "${st[@]:1}" )
          ids+=( "$cur" ); seen[$cur]=1
          local -a ch=()
          local ci
          for j in "${all[@]}"; do
            [ "${I_PKEY[$j]}" = "${I_KEY[$cur]}" ] || continue
            [ -n "${seen[$j]+x}" ] && continue
            ch+=( "$j" )
          done
          for (( ci=${#ch[@]}-1; ci>=0; ci-- )); do
            st=( "${ch[$ci]}" "${st[@]}" )
          done
        done
      done
      for r in "${all[@]}"; do
        [ -z "${I_PKEY[$r]}" ] && continue
        [ -n "${seen[$r]+x}" ] && continue
        ids+=( "$r" ); seen[$r]=1
      done
      unset seen all order r j isp cur st
    fi
    for i in "${ids[@]}"; do
      if [ "$s" = "system" ] && [ "${I_IND[$i]}" = "  " ]; then
        echo ""
      elif [ "$s" = "AI" ] && [ "${I_KEY[$i]}" = "tools:ollama" ]; then
        echo ""
      fi
      local nm="${I_IND[$i]}${I_NAME[$i]}"
      printf "%s%s%s" "${I_COL[$i]}" "$nm" "$RESET"
      local pad=$(( W - ${#nm} )) j
      for (( j=0; j<pad; j++ )); do
        printf "."
      done
      if [ "${I_GRP[$i]}" = 1 ]; then
        printf "\n"
        continue
      fi
      case "${I_CLS[$i]}" in
        ok)   printf "  %s[ok]%s   %s\n"   "$C_OK"   "$RESET" "${I_LBL[$i]}";   n_ok=$(( n_ok + 1 ));;
        skip) printf "  %s[skip]%s %s\n"  "$C_SKIP" "$RESET" "${I_LBL[$i]}";   n_skip=$(( n_skip + 1 ));;
        fail) printf "  %s[FAIL]%s %s\n"  "$C_FAIL" "$RESET" "${I_LBL[$i]}";   n_fail=$(( n_fail + 1 ));;
        *)    printf "  [%s]   %s\n" "${I_CLS[$i]}" "${I_LBL[$i]}";;
      esac
    done
  done

  printf "\n%s  %s%d ok%s | %s%d skip%s | %s%d failed%s\n" \
    "$C_GRP" "$C_OK" "$n_ok" "$RESET" "$C_SKIP" "$n_skip" "$RESET" "$C_FAIL" "$n_fail" "$RESET"

  echo ""

  if [ "$VAGRANT_RESTART_NEEDED" = 1 ]; then
    echo ""
    printf "  %sVagrant installed in WSL — restarting in 5 seconds...%s\n" "$C_SECT" "$RESET"
    echo "  This window will close. Open a new WSL session for Vagrant to work."
    echo ""
    sleep 5
    wsl.exe --shutdown
  fi

  [ "$n_fail" -eq 0 ]
}

main() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      -v|--verbose) VERBOSE=1;;
    esac
  done

  VAGRANT_RESTART_NEEDED=0
  mkdir -p "$LOG_DIR"

  sudo -v
  # keep sudo credentials fresh for the entire run (long steps exceed the 15-min window)
  while true; do
    sudo -n true >/dev/null 2>&1 || exit 1
    sleep 60
  done &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

  run_step "system:mount shared data" "Mounting shared data" mount_data_dir
  run_step "apt:packages" "Installing apt packages" install_packages
  run_step "tools:fastfetch" "Installing Fastfetch" install_fastfetch
  run_step "tools:agent" "Installing opencode" install_opencode
  run_step "tools:tmuxai" "Installing tmuxai" install_tmuxai
  run_step "tools:ollama" "Installing Ollama" install_ollama
  run_step "tools:vagrant" "Installing vagrant" install_vagrant
  run_step "tools:cliamp" "Installing cliamp" install_cliamp
  run_step "tools:golazo" "Installing golazo" install_golazo
  run_step "tools:tdfiglet" "Installing tdfiglet" install_tdfiglet
  run_step "tools:tte" "Installing terminal effects" install_tte
  run_step "tools:rust" "Installing Rust" install_rust
  run_step "tools:silicon" "Installing silicon" install_silicon
  run_step "tools:node" "Installing Node.js" install_node
  run_step "system:set time zone" "Configuring time zone" configure_timezone
  run_step "system:link dot files" "Linking dot files" install_dotfiles
  run_step "tools:tmux-plugins" "Installing tmux plugins" install_tmux_plugins
  run_step "system:config git" "Configuring git" configure_git
  run_step "system:copy ssh keys" "Copying SSH keys" install_ssh
  run_step "system:wsl config (on host)" "Configuring WSL" install_wslconfig

  report
}

main "$@"
