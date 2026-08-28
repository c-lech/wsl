# WSL

Personal WSL environment backup and setup scripts.

```powershell
wsl --install -d Ubuntu-24.04
wsl --list --verbose
wsl --unregister Ubuntu-24.04
```

## First Installation

On a fresh WSL installation:

```bash
git clone https://github.com/c-lech/wsl.git ~/wsl
cd ~/wsl
./install.sh
```

## Structure

```text
wsl/
├── dotfiles/
│   ├── wslconfig
│   ├── bashrc
│   ├── bash_aliases
│   ├── tmux.conf
│   ├── opencode.jsonc
│   └── tmuxai.yaml
├── createenv.sh
├── install.sh
├── pull.sh
├── push.sh
└── README.md
```

## Install

`install.sh` is idempotent: it runs silently and never reinstalls what's already present
(`[skip]`); `[ok]` means something actually changed, `[FAIL]` an error. At the end it prints a
per-component status report with sub-results (ollama models, vagrant plugin) included. It
keeps running past individual failures, and verbose command output (apt, curl installers,
etc.) is saved to `~/.install-logs/` — only the tail is shown if a command fails. Use
`./install.sh -v` to watch each step live. It exits 0 when nothing failed. It:

- installs required packages (`jq`, `zstd`, `tree`, `figlet`, `cmatrix`, `mtr`, `nmap`, `netcat-openbsd`, `traceroute`, `dnsutils`, `whois`, `telnet`, `socat`, `iftop`, `net-tools`, `htop`, `btop`, `glances`, `ncdu`, `nvtop`, `iotop`, `sysstat`, `lm-sensors`, `smartmontools`, `snmp`, `ansible`, `sshpass`, `rsync`, `fzf`)
- installs `fastfetch` (from PPA)
- installs `opencode`
- installs `tmuxai`
- installs `ollama` (server + pulls `qwen3:8b`, creates `qwen3:8b-16k`)
- installs `vagrant` (HashiCorp repo) + `virtualbox_WSL2` plugin
- symlinks dotfiles (incl. opencode and tmuxai config)
- copies `dotfiles/wslconfig` as `.wslconfig` to the Windows user profile
- mounts Windows `C:\data\projects` at `$HOME/projects` (persistent via `/etc/fstab`, drvfs `metadata`)
- lets Git authenticate silently: copies `infra/git_credentials/git-credentials` to `~/.git-credentials` (chmod 600) and enables `credential.helper store`

Run:

```bash
cd ~/wsl
./install.sh
```

## Data Mount

Windows `C:\data\projects` is mounted at `$HOME/projects` (drvfs) and survives
restarts via `/etc/fstab`:

```text
C:\data\projects $HOME/projects drvfs defaults,metadata 0 0
```

Project work lives under `$HOME/projects` so it's accessible from both Windows and WSL.

## Dotfiles

`dotfiles/` contains `tmux.conf`, `bashrc`, `bash_aliases`, `opencode.jsonc`, `tmuxai.yaml`, `config.jsonc`, `logo.png`, and `wslconfig`.
Installation symlinks the Linux dotfiles and copies `wslconfig` as `.wslconfig` to the Windows
user profile (`C:\Users\<user>\.wslconfig`):

```text
~/.tmux.conf -> ~/wsl/dotfiles/tmux.conf
~/.bashrc    -> ~/wsl/dotfiles/bashrc
~/.bash_aliases -> ~/wsl/dotfiles/bash_aliases
~/.config/opencode/opencode.jsonc -> ~/wsl/dotfiles/opencode.jsonc
~/.config/tmuxai/config.yaml      -> ~/wsl/dotfiles/tmuxai.yaml
~/.config/fastfetch/config.jsonc  -> ~/wsl/dotfiles/config.jsonc
~/.config/fastfetch/logo.png      -> ~/wsl/dotfiles/logo.png
C:\Users\<user>\.wslconfig <- ~/wsl/dotfiles/wslconfig  (copied, not symlinked)
```

`.wslconfig` is copied rather than symlinked since it lives on the Windows side.
An existing file that differs is overwritten. Changes
take effect after `wsl --shutdown` in PowerShell, then reopening WSL.

## Vagrant / Development VMs

`createenv.sh` recreates the development VMs (destroy + up):

```bash
./createenv.sh
```

Environments are defined in the script (`VAGRANT_DIR` + env names) under the
Windows-side vagrant folder.

## Update Repository

```bash
./push.sh "update message"
```

## Update Local Copy

```bash
./pull.sh
```

## Requirements

- WSL
- Ubuntu/Debian based distribution
- Git
