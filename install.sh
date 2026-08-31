#!/bin/bash

set -euo pipefail

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.install-logs"

C_OK=''
C_SKIP=''
C_FAIL=''
C_GRP=''
RESET=''
if [ -t 1 ]; then
  C_OK=$'\033[32m'
  C_SKIP=$'\033[33m'
  C_FAIL=$'\033[31m'
  C_GRP=$'\033[1;36m'
  RESET=$'\033[0m'
fi

VERBOSE=0

declare -A STATUS NOTE IN_ORDER
ORDER=()

step() {
  if [ "$VERBOSE" = 1 ]; then
    echo "  -> $1"
  fi
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

log_tail() {
  local f="$LOG_DIR/$1"
  echo "  ! last output of $f:"
  tail -n 20 "$f" 2>/dev/null | sed 's/^/    /'
}

apt_update() {
  step "apt update"
  if ! sudo apt update >> "$LOG_DIR/apt-update.log" 2>&1; then
    log_tail apt-update.log
    return 1
  fi
}

install_packages() {
  step "checking packages"
  local packages=(jq zstd tree figlet cmatrix mc \
    mtr nmap traceroute dnsutils whois telnet socat iftop net-tools \
    htop btop glances ncdu nvtop iotop sysstat lm-sensors smartmontools snmp \
    ansible sshpass fzf wl-clipboard chafa yq \
    alsa-utils libasound2-plugins pulseaudio-utils ffmpeg yt-dlp)

  local pkg to_install=()
  for pkg in "${packages[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      record "apt:$pkg" skip "already present"
    else
      to_install+=("$pkg")
    fi
  done

  if [ "${#to_install[@]}" -eq 0 ]; then
    step "no packages to install"
    return 0
  fi

  if ! apt_update; then
    for pkg in "${to_install[@]}"; do
      record "apt:$pkg" fail "failed (apt update)"
    done
    return 0
  fi

  step "apt install ${#to_install[@]} packages (single run)"
  if sudo apt install -y "${to_install[@]}" >> "$LOG_DIR/apt-install.log" 2>&1; then
    for pkg in "${to_install[@]}"; do
      record "apt:$pkg" ok "installed"
    done
    return 0
  fi

  step "batch install failed, retrying individually"
  log_tail apt-install.log
  for pkg in "${to_install[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      record "apt:$pkg" ok "installed"
    elif sudo apt install -y "$pkg" >> "$LOG_DIR/apt-$pkg.log" 2>&1; then
      record "apt:$pkg" ok "installed"
    else
      record "apt:$pkg" fail "failed"
      log_tail "apt-$pkg.log"
    fi
  done
}

install_fastfetch() {
  local log="$LOG_DIR/fastfetch.log"
  if command -v fastfetch >/dev/null 2>&1; then
    record "tools:fastfetch" skip "already present"
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
  record "tools:fastfetch" ok "installed (PPA)"
}

install_opencode() {
  local log="$LOG_DIR/opencode.log"
  if [ -x "$HOME/.opencode/bin/opencode" ]; then
    if [ "$(readlink /usr/local/bin/opencode 2>/dev/null)" = "$HOME/.opencode/bin/opencode" ]; then
      record "tools:opencode" skip "already present"
    else
      echo "  -> opencode: relinking /usr/local/bin/opencode"
      sudo ln -sfn "$HOME/.opencode/bin/opencode" /usr/local/bin/opencode
      record "tools:opencode" ok "relinked"
    fi
    return 0
  fi
  step "opencode -> installing"
  if ! curl -fsSL https://opencode.ai/install | bash >> "$log" 2>&1; then
    log_tail opencode.log
    step "opencode -> install script failed, trying tarball"
    mkdir -p "$HOME/.opencode/bin"
    if ! curl -fL "https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-x64.tar.gz" \
        | tar xz -C "$HOME/.opencode/bin" >> "$log" 2>&1; then
      log_tail opencode.log
      record "tools:opencode" fail "failed"
      return 1
    fi
  fi
  sudo ln -sfn "$HOME/.opencode/bin/opencode" /usr/local/bin/opencode
  record "tools:opencode" ok "installed"
}

install_tmuxai() {
  local log="$LOG_DIR/tmuxai.log"
  if command -v tmuxai >/dev/null 2>&1; then
    record "tools:tmuxai" skip "already present"
    return 0
  fi
  step "tmuxai -> installing"
  if ! curl -fsSL https://get.tmuxai.dev | bash >> "$log" 2>&1; then
    log_tail tmuxai.log
    step "tmuxai -> install script failed, trying tarball"
    if ! curl -fL "https://github.com/alvinunreal/tmuxai/releases/latest/download/tmuxai_Linux_amd64.tar.gz" \
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

  if command -v ollama >/dev/null 2>&1; then
    record "tools:ollama" skip "already present"
  else
    step "ollama -> installing"
    if ! curl -fsSL https://ollama.com/install.sh | sh >> "$log" 2>&1; then
      log_tail ollama.log
      step "ollama -> install script failed, trying binary"
      if ! curl -fL "https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64" \
            -o /tmp/ollama >> "$log" 2>&1 \
          || ! sudo install -o root -g root -m 755 /tmp/ollama /usr/local/bin/ollama >> "$log" 2>&1; then
        rm -f /tmp/ollama
        log_tail ollama.log
        record "tools:ollama" fail "failed"
        return 1
      fi
      rm -f /tmp/ollama
    fi
    record "tools:ollama" ok "installed"
  fi

  if model_present "qwen3:8b"; then
    record "tools:ollama:model qwen3:8b" skip "already pulled"
  else
    step "ollama -> pulling qwen3:8b"
    if ollama pull qwen3:8b >> "$log" 2>&1; then
      record "tools:ollama:model qwen3:8b" ok "pulled"
    else
      record "tools:ollama:model qwen3:8b" fail "pull failed"
    fi
  fi

  if model_present "qwen3:8b-16k"; then
    record "tools:ollama:model qwen3:8b-16k" skip "already present"
  else
    step "ollama -> creating qwen3:8b-16k"
    printf 'FROM qwen3:8b\nPARAMETER num_ctx 16384\n' > /tmp/Modelfile-qwen3-16k
    if ollama create qwen3:8b-16k -f /tmp/Modelfile-qwen3-16k >> "$log" 2>&1; then
      record "tools:ollama:model qwen3:8b-16k" ok "created"
    else
      record "tools:ollama:model qwen3:8b-16k" fail "create failed"
    fi
  fi
}

install_vagrant() {
  local log="$LOG_DIR/vagrant.log"

  if dpkg -s vagrant >/dev/null 2>&1; then
    record "tools:vagrant" skip "already present"
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
    record "tools:vagrant" ok "installed"
    RESTART_NEEDED=1
  fi

  if ! command -v vagrant >/dev/null 2>&1; then
    record "tools:vagrant:virtualbox_WSL2 plugin" fail "not installed (vagrant missing)"
    return 1
  fi

  if vagrant plugin list | grep -qi virtualbox_wsl2; then
    record "tools:vagrant:virtualbox_WSL2 plugin" skip "already present"
  else
    step "vagrant plugin virtualbox_WSL2 -> installing"
    if vagrant plugin install virtualbox_WSL2 >> "$log" 2>&1; then
      record "tools:vagrant:virtualbox_WSL2 plugin" ok "installed"
      RESTART_NEEDED=1
    else
      log_tail vagrant.log
      record "tools:vagrant:virtualbox_WSL2 plugin" fail "failed"
    fi
  fi
}

install_cliamp() {
  local log="$LOG_DIR/cliamp.log"
  if command -v cliamp >/dev/null 2>&1; then
    record "tools:cliamp" skip "already present"
    return 0
  fi
  step "cliamp -> installing"
  if ! curl -fsSL https://raw.githubusercontent.com/bjarneo/cliamp/HEAD/install.sh | sh >> "$log" 2>&1; then
    log_tail cliamp.log
    record "tools:cliamp" fail "failed"
    return 1
  fi
  record "tools:cliamp" ok "installed"
}

install_node() {
  local log="$LOG_DIR/node.log"

  # nvm
  if [ -s "$HOME/.nvm/nvm.sh" ]; then
    record "tools:nvm" skip "already installed"
  else
    step "node -> installing nvm"
    if ! curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh \
        | bash >> "$log" 2>&1; then
      log_tail node.log
      record "tools:nvm" fail "failed"
      return 1
    fi
    record "tools:nvm" ok "installed"
  fi

  # Load nvm for this run (nvm is a shell function, not on PATH).
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

  # node LTS
  if command -v node >/dev/null 2>&1; then
    record "tools:node" skip "already installed ($(node --version))"
  else
    step "node -> installing LTS"
    if ! nvm install --lts >> "$log" 2>&1; then
      log_tail node.log
      record "tools:node" fail "failed"
      return 1
    fi
    record "tools:node" ok "installed ($(node --version))"
  fi

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
    record "tools:tmux-plugins" skip "already present"
  fi
}

install_dotfiles() {
  local -A links=(
    ["$HOME/.tmux.conf"]="$BASE/dotfiles/tmux.conf"
    ["$HOME/.bashrc"]="$BASE/dotfiles/bashrc"
    ["$HOME/.bash_aliases"]="$BASE/dotfiles/bash_aliases"
    ["$HOME/.asoundrc"]="$BASE/dotfiles/asoundrc"
    ["$HOME/.config/opencode/opencode.jsonc"]="$BASE/dotfiles/opencode.jsonc"
    ["$HOME/.config/tmuxai/config.yaml"]="$BASE/dotfiles/tmuxai.yaml"
    ["$HOME/.config/fastfetch/config.jsonc"]="$BASE/dotfiles/config.jsonc"
    ["$HOME/.config/fastfetch/logo.png"]="$BASE/dotfiles/logo.png"
  )

  local link up=1
  for link in "${!links[@]}"; do
    if [ "$(readlink "$link" 2>/dev/null)" != "${links[$link]}" ]; then
      up=0
      break
    fi
  done

  if [ "$up" = 1 ] && [ -f "$HOME/.config/fastfetch/logo.txt" ]; then
    record "system:dotfiles" skip "already linked"
    return 0
  fi

  step "dotfiles -> symlinking"

  ln -sfn "$BASE/dotfiles/tmux.conf" "$HOME/.tmux.conf"
  step "dotfiles -> ~/.bashrc"
  ln -sfn "$BASE/dotfiles/bashrc" "$HOME/.bashrc"
  step "dotfiles -> ~/.bash_aliases"
  ln -sfn "$BASE/dotfiles/bash_aliases" "$HOME/.bash_aliases"
  step "dotfiles -> ~/.asoundrc"
  ln -sfn "$BASE/dotfiles/asoundrc" "$HOME/.asoundrc"

  step "dotfiles -> ~/.config/opencode/opencode.jsonc"
  mkdir -p "$HOME/.config/opencode"
  ln -sfn "$BASE/dotfiles/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"

  step "dotfiles -> ~/.config/tmuxai/config.yaml"
  mkdir -p "$HOME/.config/tmuxai"
  ln -sfn "$BASE/dotfiles/tmuxai.yaml" "$HOME/.config/tmuxai/config.yaml"

  step "dotfiles -> ~/.config/fastfetch"
  mkdir -p "$HOME/.config/fastfetch"
  ln -sfn "$BASE/dotfiles/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
  ln -sfn "$BASE/dotfiles/logo.png" "$HOME/.config/fastfetch/logo.png"

  step "dotfiles -> rendering fastfetch logo"
  if ! chafa --size 60x30 --symbols block+border+space-wide-inverted \
        "$HOME/.config/fastfetch/logo.png" > "$HOME/.config/fastfetch/logo.txt" 2> "$LOG_DIR/dotfiles.log"; then
    log_tail dotfiles.log
    record "system:dotfiles" fail "failed (logo render)"
    return 1
  fi

  record "system:dotfiles" ok "8 symlinks + logo"
}

install_wslconfig() {
  if ! command -v cmd.exe >/dev/null 2>&1 || ! command -v wslpath >/dev/null 2>&1; then
    record "system:wslconfig" skip "not on WSL"
    return 0
  fi

  local win_home win_config
  win_home="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
  if [ -z "$win_home" ]; then
    record "system:wslconfig" skip "no Windows profile"
    return 0
  fi

  win_config="$(wslpath -u "$win_home")/.wslconfig"
  if [ ! -d "$(dirname "$win_config")" ]; then
    record "system:wslconfig" skip "Windows profile unreachable"
    return 0
  fi

  if [ -f "$win_config" ]; then
    if cmp -s "$BASE/dotfiles/wslconfig" "$win_config"; then
      record "system:wslconfig" skip "already in sync"
    else
      step "wslconfig -> updating"
      cp "$BASE/dotfiles/wslconfig" "$win_config"
      record "system:wslconfig" ok "updated"
      RESTART_NEEDED=1
    fi
  else
    step "wslconfig -> installing"
    cp "$BASE/dotfiles/wslconfig" "$win_config"
    record "system:wslconfig" ok "installed"
    RESTART_NEEDED=1
  fi
}

mount_data_dir() {
  local note="" changed=0

  if mountpoint -q "$HOME/projects"; then
    note="already mounted"
  else
    step "mount data -> creating $HOME/projects"
    mkdir -p "$HOME/projects"

    local uid gid
    uid="$(id -u)"
    gid="$(id -g)"
    step "mount data -> C:\\data\\projects -> $HOME/projects (uid=$uid, gid=$gid)"
    if ! sudo mount -t drvfs -o "defaults,metadata,uid=$uid,gid=$gid" \
          'C:\data\projects' "$HOME/projects" >> "$LOG_DIR/mount.log" 2>&1; then
      log_tail mount.log
      record "system:mount" fail "mount failed"
      return 1
    fi
    sleep 2
    note="mounted"
    changed=1
  fi

  if grep -Fq 'C:\data\projects' /etc/fstab 2>/dev/null; then
    note="$note, fstab already set"
  else
    local uid gid
    uid="$(id -u)"
    gid="$(id -g)"
    step "mount data -> adding to /etc/fstab"
    echo "C:\\data\\projects $HOME/projects drvfs defaults,metadata,uid=$uid,gid=$gid 0 0" \
      | sudo tee -a /etc/fstab >> "$LOG_DIR/mount.log" 2>&1
    note="$note, fstab added"
    changed=1
  fi

  if [ "$changed" = 1 ]; then
    record "system:mount" ok "$note"
  else
    record "system:mount" skip "$note"
  fi
}

install_ssh() {
  local src="$HOME/projects/infra/wsl_ssh_key"
  if [ ! -f "$src/id_ed25519" ]; then
    record "system:ssh" skip "no source key"
    return 0
  fi
  if [ -f "$HOME/.ssh/id_ed25519" ] \
      && [ -f "$HOME/.ssh/id_ed25519.pub" ] \
      && cmp -s "$src/id_ed25519" "$HOME/.ssh/id_ed25519" \
      && cmp -s "$src/id_ed25519.pub" "$HOME/.ssh/id_ed25519.pub"; then
    record "system:ssh" skip "keys already in place"
    return 0
  fi
  step "ssh -> copying keys"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  cp "$src/id_ed25519" "$HOME/.ssh/"
  chmod 600 "$HOME/.ssh/id_ed25519"
  cp "$src/id_ed25519.pub" "$HOME/.ssh/"
  chmod 644 "$HOME/.ssh/id_ed25519.pub"
  record "system:ssh" ok "keys copied"
}

install_git_credentials() {
  local src="$HOME/projects/infra/git_credentials/git-credentials"
  if [ ! -f "$src" ]; then
    record "system:git-credentials" skip "no source credentials"
    return 0
  fi
  if [ -f "$HOME/.git-credentials" ] && cmp -s "$src" "$HOME/.git-credentials"; then
    record "system:git-credentials" skip "already in place"
    return 0
  fi
  step "git-credentials -> copying"
  cp "$src" "$HOME/.git-credentials"
  chmod 600 "$HOME/.git-credentials"
  record "system:git-credentials" ok "credentials copied"
}

configure_timezone() {
  local tz="America/Argentina/Buenos_Aires"
  if [ "$(timedatectl show -p Timezone --value 2>/dev/null)" = "$tz" ]; then
    record "system:timezone" skip "already set ($tz)"
  else
    step "timezone -> setting to $tz"
    if ! sudo timedatectl set-timezone "$tz" \
        && ! sudo ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime; then
      record "system:timezone" fail "failed"
      return 1
    fi
    record "system:timezone" ok "set to $tz"
  fi
}

configure_git() {
  if [ -n "$(git config --global user.name)" ] && [ -n "$(git config --global user.email)" ]; then
    record "system:git" skip "already configured"
  else
    step "git -> setting identity"
    git config --global user.name "c-lech"
    git config --global user.email "126396070+c-lech@users.noreply.github.com"
    record "system:git" ok "configured"
  fi
  if [ "$(git config --global credential.helper)" != "store" ]; then
    step "git -> enabling credential.helper store"
    git config --global credential.helper store
    record "system:git" ok "credential helper set"
  fi
}

run_step() {
  local key="$1"
  shift
  set +e
  "$@"
  local rc=$?
  set -e
  if [ "$rc" -ne 0 ] && [ -z "${STATUS[$key]+x}" ]; then
    record "$key" fail "failed (exit $rc)"
  fi
  return 0
}

report() {
  echo ""
  local -A group_label=([apt]="apt packages" [tools]="tools" [system]="system")
  local groups=(apt tools system)
  local g k
  local n_ok=0 n_skip=0 n_fail=0

  local W=0
  for g in "${groups[@]}"; do
    for k in "${ORDER[@]}"; do
      [[ "$k" == "$g:"* ]] || continue
      local rest="${k#"$g:"}"
      local pre
      if [[ "$rest" == *":"* ]]; then
        pre="    ${rest#*:}"
      else
        pre="  $rest"
      fi
      if [ "${#pre}" -gt "$W" ]; then
        W="${#pre}"
      fi
    done
  done

  for g in "${groups[@]}"; do
    local names=() cls=() lbls=()
    local empty=1

    for k in "${ORDER[@]}"; do
      [[ "$k" == "$g:"* ]] || continue
      empty=0
      local rest="${k#"$g:"}"
      local indent name
      if [[ "$rest" == *":"* ]]; then
        indent="    "
        name="${rest#*:}"
      else
        indent="  "
        name="$rest"
      fi
      local pre="${indent}${name}"
      names+=("$pre")
      cls+=("${STATUS[$k]}")
      lbls+=("${NOTE[$k]}")
    done

    [ "$empty" = 1 ] && continue

    echo "${C_GRP}${group_label[$g]}:${RESET}"
    local i
    for i in "${!names[@]}"; do
      printf "%s" "${names[$i]}"
      local w="$W"
      local pad=$(( w - ${#names[$i]} ))
      local j
      for (( j=0; j<pad; j++ )); do
        printf "."
      done
      case "${cls[$i]}" in
        ok)   printf "  %s[ok]%s   %s\n"   "$C_OK"   "$RESET" "${lbls[$i]}";   n_ok=$(( n_ok + 1 ));;
        skip) printf "  %s[skip]%s %s\n"  "$C_SKIP" "$RESET" "${lbls[$i]}";   n_skip=$(( n_skip + 1 ));;
        fail) printf "  %s[FAIL]%s %s\n"  "$C_FAIL" "$RESET" "${lbls[$i]}";   n_fail=$(( n_fail + 1 ));;
        *)    printf "  [%s]   %s\n" "${cls[$i]}" "${lbls[$i]}";;
      esac
    done
    echo ""
  done

  printf "%s  %s%d ok%s | %s%d skip%s | %s%d failed%s\n" \
    "$C_GRP" "$C_OK" "$n_ok" "$RESET" "$C_SKIP" "$n_skip" "$RESET" "$C_FAIL" "$n_fail" "$RESET"

  echo ""

  if [ "$RESTART_NEEDED" = 1 ]; then
    echo "  Run 'wsl --shutdown' in PowerShell and reopen to apply changes."
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

  RESTART_NEEDED=0
  mkdir -p "$LOG_DIR"

  run_step "apt:packages" install_packages
  run_step "system:timezone" configure_timezone
  run_step "tools:fastfetch" install_fastfetch
  run_step "tools:opencode" install_opencode
  run_step "tools:tmuxai" install_tmuxai
  #run_step "tools:ollama" install_ollama
  run_step "tools:vagrant" install_vagrant
  run_step "tools:cliamp" install_cliamp
  run_step "tools:node" install_node
  run_step "system:dotfiles" install_dotfiles
  run_step "system:wslconfig" install_wslconfig
  run_step "tools:tmux-plugins" install_tmux_plugins
  run_step "system:git" configure_git
  run_step "system:mount" mount_data_dir
  run_step "system:ssh" install_ssh
  run_step "system:git-credentials" install_git_credentials

  report
}

main "$@"
