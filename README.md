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
│   ├── tmux.conf
│   ├── asoundrc
│   ├── vimrc
│   ├── opencode.jsonc
│   ├── tmuxai.yaml
│   ├── cliamp.toml
│   ├── cliamp-radios.toml
│   ├── config.jsonc
│   ├── fastfetchlogo.png
│   ├── golazo-settings.yaml
│   └── windows/
│       ├── wt-settings.json
│       ├── yasb-config.yaml
│       ├── yasb-styles.css
│       ├── glazewm-config.yaml
│       └── vscode-settings.json
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

- installs required packages (`btop`, `htop`, `glances`, `tree`, `ncdu`, `iotop`, `sysstat`, `mtr`, `nmap`, `traceroute`, `dnsutils`, `whois`, `telnet`, `iftop`, `net-tools`, `snmp`, `socat`, `gping`, `lm-sensors`, `smartmontools`, `nvtop`, `lnav`, `ansible`, `sshpass`, `fzf`, `mc`, `jq`, `yq`, `figlet`, `cmatrix`, `python3-pip`, `pipx`, `chafa`, `wl-clipboard`, `ffmpeg`, `libasound2-plugins`, `pulseaudio-utils`, and the `cargo` build deps `pkg-config`, `libfontconfig1-dev`, `libfreetype-dev`, `libxcb-composite0-dev`, `libharfbuzz-dev`, `libexpat1-dev`)
- installs `fastfetch` (from PPA)
- installs `opencode`
- installs `tmuxai`
- installs `ollama` (server + pulls `qwen3:8b`, creates `qwen3:8b-16k`)
- installs `vagrant` (HashiCorp repo) + `virtualbox_WSL2` plugin
- installs Rust (`cargo`, via rustup) and `silicon` (code screenshot tool, `cargo install`), `watchexec` (file-change trigger, `cargo install` with GitHub binary fallback)
- installs `golazo` (football TUI)
- installs `gonzo` (log analysis TUI, GitHub release binary with go install fallback)
- symlinks dotfiles (incl. opencode and tmuxai config)
- copies `dotfiles/wslconfig` as `.wslconfig` to the Windows user profile
- copies `dotfiles/windows/` (Windows Terminal, YASB, GlazeWM, VS Code) to their config locations, skipping any app that isn't installed
- copies `dotfiles/cliamp.toml` to `~/.config/cliamp/config.toml` (symlinks `cliamp-radios.toml`)
- mounts Windows `C:\data\shared` at `$HOME/shared` (persistent via `/etc/fstab`, drvfs `metadata`)
- lets Git authenticate silently: copies `infra/git_credentials/git-credentials` to `~/.git-credentials` (chmod 600) and enables `credential.helper store`

Run:

```bash
cd ~/wsl
./install.sh
```

## Ollama + Multiple WSL Distros — Case Study

### The case

A fresh `ubu2` was created (`wsl --install -d Ubuntu-26.04 --name ubu2`), then
`./install.sh -vv` on it reported `[skip] already pulled` / `already created` for
both models — but the distro was brand new. Impossible, or a bug?

### The findings

1. `ubu2`'s storage folder (`C:\Users\<user>\AppData\Local\wsl\{...}`) was
   created the same day — genuinely fresh, not a clone or restored snapshot.
2. The models showed `MODIFIED 14 hours ago` — *older than ubu2 itself*. They
   could not be ubu2's.
3. `wsl -d ubu2 -e ollama list` returned the **same models** as `wsl -d ubu -e ollama list`.
4. `pgrep -af ollama` on each distro: **ubu** runs `ollama serve`; **ubu2** runs
   **no server** — yet both list identical models (same IDs, same size).
5. Root cause: WSL2 runs all distros inside **one shared VM**, so they share the
   same `127.0.0.1` loopback. The script's `ollama list` on ubu2 was answered by
   **ubu's** server over that shared loopback.

### The conclusion

- Not a bug — not in `install.sh`, not in the distro naming, and nothing leaked
  from Windows.
- `install.sh` reported the truth: the models *do* exist — just on another
  distro. Its one wrong assumption was that `ollama list` reflects **this**
  distro's store; on WSL2 it reflects whatever server owns port `11434`.
- The skip notice states which case you're in:
  `already pulled (local server)` vs `already pulled (on another distro, shared loopback)`.
- **Deliberately kept shared:** one ~10 GB model store, usable from every distro,
  nothing duplicated. Per-distro isolation was considered and rejected — it would
  duplicate ~10 GB per distro and fight WSL2's shared-VM design.

The two-word tell is in the skip line: `local server` = this distro owns it;
`shared loopback` = another distro serves it. Recreate the mystery with:
`wsl -d <distro> -e bash -lc 'pgrep -af ollama; ollama list'`.

## Data Mount

Windows `C:\data\shared` is mounted at `$HOME/shared` (drvfs) and survives
restarts via `/etc/fstab`:

```text
C:\data\shared $HOME/shared drvfs defaults,metadata 0 0
```

Work and data live under `$HOME/shared` so they're accessible from both Windows and WSL.

Machine-local infra lives under `$HOME/shared/infra/` (not versioned): `git_credentials/`,
`wsl_ssh_key/`, `vagrant/`, and — since it's just SSH addresses — the aliases file at
`$HOME/shared/infra/bash_aliases/bash_aliases`, symlinked as `~/.bash_aliases`.

## Dotfiles

`dotfiles/` contains `tmux.conf`, `bashrc`, `vimrc`, `asoundrc`, `opencode.jsonc`, `tmuxai.yaml`, `cliamp.toml`, `cliamp-radios.toml`, `config.jsonc`, `fastfetchlogo.png`, `golazo-settings.yaml`, `wslconfig`, and `windows/`.
Installation symlinks the Linux dotfiles, copies `wslconfig` as `.wslconfig` to the Windows
user profile (`C:\Users\<user>\.wslconfig`), and copies `windows/` to each app's own
config location:

```text
~/.tmux.conf -> ~/wsl/dotfiles/tmux.conf
~/.bashrc    -> ~/wsl/dotfiles/bashrc
~/.vimrc     -> ~/wsl/dotfiles/vimrc
~/.bash_aliases -> ~/shared/infra/bash_aliases/bash_aliases   (machine-local, linked if present)
~/.config/opencode/opencode.jsonc -> ~/wsl/dotfiles/opencode.jsonc
~/.config/tmuxai/config.yaml      -> ~/wsl/dotfiles/tmuxai.yaml
~/.config/fastfetch/config.jsonc  -> ~/wsl/dotfiles/config.jsonc
~/.config/fastfetch/fastfetchlogo.png -> ~/wsl/dotfiles/fastfetchlogo.png
~/.config/golazo/settings.yaml    -> ~/wsl/dotfiles/golazo-settings.yaml
~/.config/cliamp/radios.toml      -> ~/wsl/dotfiles/cliamp-radios.toml
~/.config/cliamp/config.toml      <- ~/wsl/dotfiles/cliamp.toml  (copied, not symlinked)
C:\Users\<user>\.wslconfig <- ~/wsl/dotfiles/wslconfig  (copied, not symlinked)
```

`~/.bash_aliases` links to `~/shared/infra/bash_aliases/bash_aliases` (shared storage,
not the repo) — SSH addresses are machine-local. `install.sh` links it only when the
file exists and skips it otherwise, so fresh machines don't fail.

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

## Windows App Configs

`dotfiles/windows/` holds one config file per Windows app. `install.sh` copies each
to its native location, then reports `[ok]` (copied), `[skip] already copied`
(identical, nothing to do), or `[skip] <app> not installed`:

| Repo file | Windows location |
| --- | --- |
| `wt-settings.json` | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal*\LocalState\settings.json` |
| `yasb-config.yaml` | `%USERPROFILE%\.config\yasb\config.yaml` |
| `yasb-styles.css` | `%USERPROFILE%\.config\yasb\styles.css` |
| `glazewm-config.yaml` | `%USERPROFILE%\.glzr\glazewm\config.yaml` |
| `vscode-settings.json` | `%APPDATA%\Code\User\settings.json` |

All five are copied, never symlinked, for the same reason `.wslconfig` is: they live
on the Windows side, where a link would not resolve.

Windows Terminal is looked up by glob because its package folder name carries the
release channel, so one copy covers Stable, Preview, and Canary. Unpackaged builds
(GitHub, Scoop, Chocolatey) keep `settings.json` in
`%LOCALAPPDATA%\Microsoft\Windows Terminal\` instead, and that path is checked too —
whichever the machine has wins.

An app whose config directory doesn't exist is skipped, never created. An empty
directory isn't a valid config location, so writing into one would only leave stray
files for an app that isn't installed.

Copying runs one way, WSL to Windows. If you change a setting inside an app's own
UI, the repo copy goes stale and re-running `./install.sh` overwrites your change;
edit `dotfiles/windows/` and `./push.sh` instead. This matters more for these files
than for `.wslconfig` — VS Code and GlazeWM settings change far more often.

`yasb-config.yaml` hardcodes `C:\Users\benito\` in its `bitcoin` and `dolar` widget
definitions, so those two widgets need that exact account name to resolve. The rest
of the file is username-independent, as is the `C:\data` menu entry at the end of it.

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
