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
│   ├── .wslconfig
│   ├── bashrc
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

`install.sh` (idempotent, each step reports installed/skipped):

- installs required packages (`jq`, `zstd`, `tree`, `ansible`, `sshpass`, `figlet`, `cmatrix`)
- installs `opencode`
- installs `tmuxai`
- installs `ollama` (server + pulls `qwen3:8b`)
- installs `vagrant` (HashiCorp repo) + `virtualbox_WSL2` plugin
- creates the projects directory
- symlinks dotfiles (incl. opencode and tmuxai config)
- copies `dotfiles/.wslconfig` to the Windows user profile
- mounts Windows `C:\data` at `/data` (persistent via `/etc/fstab`, drvfs `metadata`)

Run:

```bash
cd ~/wsl
./install.sh
```

## Data Mount

Windows `C:\data` is mounted at `/data` (drvfs) and survives restarts via
`/etc/fstab`:

```text
C:\data /data drvfs defaults,metadata 0 0
```

Project work lives under `/data` so it's accessible from both Windows and WSL.

## Dotfiles

`dotfiles/` contains `tmux.conf`, `bashrc`, `opencode.jsonc`, `tmuxai.yaml`, and `.wslconfig`.
Installation symlinks the Linux dotfiles and copies `.wslconfig` to the Windows
user profile (`C:\Users\<user>\.wslconfig`):

```text
~/.tmux.conf -> ~/wsl/dotfiles/tmux.conf
~/.bashrc    -> ~/wsl/dotfiles/bashrc
~/.config/opencode/opencode.jsonc -> ~/wsl/dotfiles/opencode.jsonc
~/.config/tmuxai/config.yaml      -> ~/wsl/dotfiles/tmuxai.yaml
C:\Users\<user>\.wslconfig <- ~/wsl/dotfiles/.wslconfig  (copied, not symlinked)
```

`.wslconfig` is copied rather than symlinked since it lives on the Windows side.
An existing file that differs is backed up to `.wslconfig.bak` first. Changes
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
