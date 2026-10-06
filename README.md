# WSL

My WSL setup: one script that installs the tools, sets up the system and puts my
dotfiles in place, plus a second script that pulls Windows app settings into the
repo.

## Requirements

- WSL2 with Ubuntu or Debian
- `sudo`, `apt` and `curl`
- `git`, to clone this repo
- `C:\data\shared` on the Windows side (it becomes `~/shared`)

Everything else is installed by `install.sh` itself: `chafa`, `boxes`, `make`,
`gcc`, `go`, `pipx`, `python3-pip`, `node` and `npm` (through nvm), and
`cfonts`. The ASCII tools land in the same run that renders the fastfetch logo,
so `chafa` is already on `PATH` when it is used.

`gpg` is also needed, but only when the script sets up vagrant. It is not in the
package list.

## Quick start

```bash
git clone https://github.com/c-lech/wsl.git
cd wsl
./install.sh
```

The first run asks for your sudo password. The whole run takes a while because it
compiles some tools from source.

## Options

| Flag | What it does |
|---|---|
| *(none)* | runs quiet, prints only the final report |
| `-v`, `--verbose` | step names, time per step, log path |
| `-vv`, `--very-verbose` | the same, plus live lines read from each step's log |
| `-vvv`, `--raw` | the same, plus the raw log of each step |

Unknown arguments are ignored. There is no `--help` and no `--dry-run`.

## What install.sh does

Steps run in this order. A failing step is recorded and the run continues.

| Step | What it does |
|---|---|
| shared data | mounts `C:\data\shared` as `~/shared` and adds the fstab line |
| apt | installs every missing package in one run, then retries one by one if the batch fails |
| fastfetch | adds the PPA, installs fastfetch |
| opencode | install script, tarball as fallback, then links the binary into `/usr/local/bin` |
| tmuxai | `go install`, then install script, then release tarball |
| vagrant | adds the HashiCorp repo, installs vagrant and the `virtualbox_WSL2` plugin |
| cliamp | upstream install script |
| kew | clones the latest tag into `/tmp/kew`, builds it, `sudo make install` |
| golazo | `go install`, then install script, then release binary |
| gonzo | `go install`, then release tarball |
| drawbox | upstream `update.sh`, then compiles from source |
| lavat | clone, build, `sudo make install` |
| tdfiglet | clone, build, `sudo make install` |
| terminaltexteffects | `pipx install` |
| drift | `go install`, then release tarball |
| rust | rustup, minimal profile, stable toolchain |
| silicon | `cargo install silicon` |
| termshot | latest release tarball |
| watchexec | `cargo install watchexec-cli`, release tarball as fallback |
| node | nvm, then the latest LTS |
| cfonts | `npm install -g cfonts` |
| time zone | sets the time zone if it is not already set |
| dotfiles | links or copies the files listed below |
| tmux plugins | clones tpm, installs every `@plugin` in `.tmux.conf` |
| git | sets name and email if unset, enables `credential.helper store`, copies `~/.git-credentials` |
| ssh keys | copies the keys from `~/shared`, sets the right modes |
| ansible | clones `c-lech/ansible-scripts` into `/etc/ansible`, runs `ansible_users.sh init` and `add-user` |
| wsl config | links `dotfiles/wsl.conf` to `/etc/wsl.conf` |
| windows dotfiles | copies the Windows app configs to `%USERPROFILE%` |

## Packages

One `apt` call covers all of them. Packages already on the machine are left
alone.

| Group | Packages |
|---|---|
| CPU | btop, htop, glances |
| Disk | tree, ncdu, iotop, sysstat |
| Networking | mtr, nmap, traceroute, bind9-dnsutils, whois, telnet, iftop, net-tools, snmp, socat, gping |
| Hardware | lm-sensors, smartmontools, nvtop |
| Log analysis | lnav |
| Remote / Automation | ansible, sshpass |
| Files | fzf, mc |
| Parse | jq, yq |
| Misc | cava, nyancat, zstd |
| Python package managers | python3-pip, pipx |
| Cargo deps | pkg-config, libfontconfig1-dev, libfreetype-dev, libxcb-composite0-dev, libharfbuzz-dev, libexpat1-dev |
| Go | golang-go |
| cliamp deps | libasound2-plugins, pulseaudio-utils, ffmpeg |
| kew deps | git, gcc, make, pkg-config, libfaad-dev, libtag1-dev, libfftw3-dev, libopus-dev, libopusfile-dev, libvorbis-dev, libogg-dev, libchafa-dev, libglib2.0-dev, libgdk-pixbuf-2.0-dev, libdbus-1-dev |
| Fastfetch util | cpufetch |
| ASCII art | boxes, jp2a, chafa, caca-utils, figlet, cmatrix, lolcat, toilet, imagemagick |
| TMUX integration | wl-clipboard |

## Tools

| Tool | From | How |
|---|---|---|
| fastfetch | PPA | apt |
| opencode | opencode.ai | install script, tarball fallback |
| tmuxai | GitHub | `go install`, script, tarball |
| vagrant | HashiCorp | apt repo + `vagrant plugin install` |
| cliamp | cliamp.stream | install script |
| kew | GitHub | clone, `make`, `sudo make install` |
| golazo | GitHub | `go install`, script, binary |
| gonzo | GitHub | `go install`, release tarball |
| drawbox | GitHub | upstream `update.sh`, else compile |
| lavat | GitHub | clone, `make`, `sudo make install` |
| tdfiglet | GitHub | clone, `make`, `sudo make install` |
| terminaltexteffects | PyPI | `pipx install` |
| drift | GitHub | `go install`, release tarball |
| silicon | crates.io | `cargo install` |
| termshot | GitHub | release tarball |
| watchexec | crates.io | `cargo install`, tarball fallback |
| node | nvm | nvm script + `nvm install --lts` |
| cfonts | npm | `npm install -g` |
| tmux plugins | tpm | `git clone` + `install_plugins` |
| ansible scripts | GitHub | clone into `/etc/ansible` |

## Dotfiles

Most files are **linked**: `~/.bashrc` points at the repo file, so an edit in the
repo is live right away. A few are **copied**, because the app writes the file
itself, or because the value is different on every machine.

| Repo file | Target | Mode |
|---|---|---|
| `dotfiles/bashrc` | `~/.bashrc` | link |
| `dotfiles/tmux.conf` | `~/.tmux.conf` | link |
| `dotfiles/vimrc` | `~/.vimrc` | link |
| `dotfiles/asoundrc` | `~/.asoundrc` | link |
| `dotfiles/config.jsonc` | `~/.config/fastfetch/config.jsonc` | link |
| `dotfiles/fastfetchlogo.png` | `~/.config/fastfetch/fastfetchlogo.png` | link |
| `dotfiles/opencode.jsonc` | `~/.config/opencode/opencode.jsonc` | link |
| `dotfiles/golazo-settings.yaml` | `~/.config/golazo/settings.yaml` | link |
| `dotfiles/tmuxai.yaml` | `~/.config/tmuxai/config.yaml` | link |
| `dotfiles/cliamp-radios.toml` | `~/.config/cliamp/radios.toml` | link |
| `dotfiles/cliamp.toml` | `~/.config/cliamp/config.toml` | copy (`cliamp setup` writes it) |
| `dotfiles/kewrc` | `~/.config/kew/kewrc` | copy, with the music folder filled in |
| _(generated from the png)_ | `~/.config/fastfetch/fastfetchlogo.txt` | rendered once with chafa |
| — | `~/.bash_aliases` | link from `~/shared`, skipped if missing |
| `dotfiles/wsl.conf` | `/etc/wsl.conf` | link |

`dotfiles/kewrc` keeps the tag `%%MUSIC_PATH%%` in the repo. The script replaces
it with `~/shared/music` in the copy only, so the repo file stays the same on
every machine. Edit settings in the repo file and run `./install.sh` again; a
file written by the app in your home folder will be put back to the repo version.

## Shared data

`C:\data\shared` is mounted as `~/shared` through drvfs, with your own uid and
gid, `umask=22` and `fmask=11` (files land as 644). The line is added to
`/etc/fstab` so it mounts on every boot.

Three things are read from there:

| Source | Target |
|---|---|
| `~/shared/infra/bash_aliases/bash_aliases` | `~/.bash_aliases` |
| `~/shared/infra/ssh_keys/` | `~/.ssh/id_ed25519` (600) and `.pub` (644) |
| `~/shared/infra/git_credentials/git-credentials` | `~/.git-credentials` (600) |

Secrets live on that share and never in the repo. If a file is missing the step
is skipped, it does not fail.

## Windows app configs

These go both ways.

- `./update_winfiles.sh` pulls them from Windows into `dotfiles/windows/`, then
  tells you to run `./push.sh` if anything changed. It skips files that are
  already identical.
- `install.sh` pushes them from the repo back to `%USERPROFILE%`.

Files: `.wslconfig`, GlazeWM `config.yaml`, YASB `config.yaml` and `styles.css`,
VS Code `settings.json`, Windows Terminal `settings.json`.

They are copied, not linked. The repo is on ext4 and the target is on drvfs, so
a link would reach Windows as an empty text file instead of the file. If the app
is not installed the step is skipped and the folder is not created.

Windows Terminal from the Store or winget is an MSIX package, so its settings
live in a folder whose name carries the release channel. The script looks for
`Packages/Microsoft.WindowsTerminal*/LocalState`. Installs from GitHub, Scoop or
Chocolatey keep the settings in a plain folder instead, and that path is tried
too.

## Logs and troubleshooting

Every step writes to `~/.install-logs/<step>.log`. With `-v` a failed step shows
its last five lines and the path to the full log.

The exit code is 0 only when nothing failed.

The report groups steps by area and prints `ok`, `skip` or `FAIL` for each one,
with a count and the total time at the end.

A few things you may see:

- The script asks for sudo at the start and keeps the password alive in the
  background, because some steps run longer than the 15 minute sudo window.
- After a fresh vagrant install it tells you to restart WSL before using it.
- `~/.config/tmux/plugins` gets repaired if a `@plugin` in `.tmux.conf` is
  missing.

## Idempotency

Run it as many times as you want. Before touching anything the script checks:

- packages with `dpkg -s`
- tools with `command -v`
- links with `readlink`
- copies with `cmp`

`skip` means "already correct", not "failed".

## Known quirks

- The time on `~/.config/kew/kewrc` changes every time you close kew. Kew
  rewrites its own config when it quits. The text comes back the same, so nothing
  is lost.
- The time zone (`America/Argentina/Buenos_Aires`) and the git name and email
  are written into `install.sh`. They are only applied when they are not already
  set.
- `.git-credentials` is copied once. If it already exists the script leaves it
  alone.
- SSH keys are refreshed from the share whenever the copy differs from the key in
  `~/.ssh`.
- `fastfetchlogo.txt` is rendered from `fastfetchlogo.png` only when the text
  file is missing. Delete the text file to render it again.

## Repo layout

| Path | What it is |
|---|---|
| `install.sh` | the installer described above |
| `update_winfiles.sh` | pulls Windows app configs into the repo |
| `dotfiles/` | files that go into your home folder |
| `dotfiles/windows/` | files that go to `%USERPROFILE%` |
| `.gitignore` | keeps secrets, keys and logs out of the repo |

The other scripts in the root are standalone helpers and are not run or touched
by `install.sh`: `checkbridge.sh`, `colorpicker.sh`, `diff.sh`, `do.sh`,
`fileexplorer.sh`, `notifywin.sh`, `push.sh`, `runssh.sh`, `runtmux.sh`,
`save.sh`, `saveclip2img.sh`, `saveclip2txt.sh`, `savecmd2img.sh`,
`savecmd2txt.sh`, `saveshotscreen.sh`, `saveshotwin.sh`, `savetmux.sh`,
`savetxt2img.sh`, `vvm.sh`.

## Maintenance

To add a tool:

1. Write `install_<name>()` that records its result with `record "key" class note`.
2. Add a `run_step "key" "Label" --log <name>.log install_<name>` line in `main()`.
3. Add the key to the map at the top of `report()` so it shows up in the right
   section.

To add a dotfile, add one line to the `entries` list in `install_dotfiles()`:
`"$HOME/.config/app/app.conf|$BASE/dotfiles/app.conf|link"`, or `copy` instead of
`link`.

The order of the `entries` list is the order shown in the report, not the order
they are installed in.

## Security

- `.gitignore` blocks credentials, keys, `.env` files and logs.
- Secrets are read from `~/shared` at install time and never stored in the repo.
- `~/.ssh` is 700, the private key 600, the public key 644, `.git-credentials`
  600.