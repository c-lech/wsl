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
│   └── tmux.conf
├── projects/
├── install.sh
├── push.sh
├── pull.sh
└── README.md
```

## Install

The `install.sh` script:

- installs required packages
- configures dotfiles
- creates required directories

Run:

```bash
cd ~/wsl
./install.sh
```

## Dotfiles

Configuration files are stored in:

```text
dotfiles/
```

Example:

```text
dotfiles/tmux.conf
```

The installation creates:

```text
~/.tmux.conf -> ~/wsl/dotfiles/tmux.conf
```

Changes made to files inside `dotfiles/` are immediately available through the symlink.

## Projects

The `projects/` directory is reserved for common projects shared between WSL installations.

Example:

```text
projects/
├── project1/
├── project2/
└── ...
```

## Update Repository

After modifying files:

```bash
./push.sh "update message"
```

Example:

```bash
./push.sh "update tmux configuration"
```

This performs:

```bash
git add .
git commit -m "update message"
git push
```

## Update Local Copy

On another WSL machine:

```bash
./pull.sh
```

This performs:

```bash
git pull
```

## Requirements

- WSL
- Ubuntu/Debian based distribution
- Git
