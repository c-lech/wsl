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
│   ├── asoundrc
│   ├── opencode.jsonc
│   ├── tmuxai.yaml
│   ├── cliamp.toml
│   ├── cliamp-radios.toml
│   ├── config.jsonc
│   ├── logo.png
│   └── golazo-settings.yaml
├── createenv.sh
├── install.sh
├── tmux5.sh
├── tdf-show.sh
├── chafa-show.sh
├── diff.sh
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

- installs required packages (`btop`, `htop`, `glances`, `tree`, `ncdu`, `iotop`, `sysstat`, `mtr`, `nmap`, `traceroute`, `dnsutils`, `whois`, `telnet`, `iftop`, `net-tools`, `snmp`, `socat`, `gping`, `lm-sensors`, `smartmontools`, `nvtop`, `ansible`, `sshpass`, `fzf`, `mc`, `jq`, `yq`, `figlet`, `cmatrix`, `python3-pip`, `pipx`, `chafa`, `wl-clipboard`, `ffmpeg`, `libasound2-plugins`, `pulseaudio-utils`, and the `cargo` build deps `pkg-config`, `libfontconfig1-dev`, `libfreetype-dev`, `libxcb-composite0-dev`, `libharfbuzz-dev`, `libexpat1-dev`)
- installs `fastfetch` (from PPA)
- installs `opencode`
- installs `tmuxai`
- installs `ollama` (server + pulls `qwen3:8b`, creates `qwen3:8b-16k`)
- installs `vagrant` (HashiCorp repo) + `virtualbox_WSL2` plugin
- installs Rust (`cargo`, via rustup) and `silicon` (code screenshot tool, `cargo install`), `watchexec` (file-change trigger, `cargo install` with GitHub binary fallback)
- installs `golazo` (football TUI)
- symlinks dotfiles (incl. opencode and tmuxai config)
- copies `dotfiles/wslconfig` as `.wslconfig` to the Windows user profile
- copies `dotfiles/cliamp.toml` to `~/.config/cliamp/config.toml` (symlinks `cliamp-radios.toml`)
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

`dotfiles/` contains `tmux.conf`, `bashrc`, `bash_aliases`, `asoundrc`, `opencode.jsonc`, `tmuxai.yaml`, `cliamp.toml`, `cliamp-radios.toml`, `config.jsonc`, `logo.png`, `golazo-settings.yaml`, and `wslconfig`.
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
~/.config/golazo/settings.yaml    -> ~/wsl/dotfiles/golazo-settings.yaml
~/.config/cliamp/radios.toml      -> ~/wsl/dotfiles/cliamp-radios.toml
~/.config/cliamp/config.toml      <- ~/wsl/dotfiles/cliamp.toml  (copied, not symlinked)
C:\Users\<user>\.wslconfig <- ~/wsl/dotfiles/wslconfig  (copied, not symlinked)
```

`cliamp/config.toml` is copied rather than symlinked since cliamp rewrites it on
its own (atomic save replacing any symlink). The repo file is the seed for fresh
installs; only your own setting changes need syncing back to the repo.
`cliamp/radios.toml` stays symlinked — cliamp never writes it.

`.wslconfig` is copied rather than symlinked since it lives on the Windows side.
An existing file that differs is overwritten. Changes
take effect after `wsl --shutdown` in PowerShell, then reopening WSL.

`/etc/wsl.conf` intentionally has no `[user] default=`, so WSL logs in as the
distro's install-time default user. This keeps the shared config portable
instead of hardcoding a username. To force a specific user on one machine, run
once from PowerShell: `wsl --manage <distro> --set-default-user <user>`.
After pulling, re-run `install.sh` (re-links `/etc/wsl.conf`) or check for a
stale `[user]` section locally, then `wsl --shutdown`.

Note: on WSLg, audio travels through the RDP bridge — if cliamp audio stutters or
"corks" after a while, update WSL itself (`wsl.exe --update`, then `wsl.exe
--shutdown`) rather than touching cliamp's buffer settings.

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
