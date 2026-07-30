# WSL

Personal WSL environment backup and setup scripts.

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

Clone the repository:

```bash
git clone https://github.com/c-lech/wsl.git ~/wsl
```

Run setup:

```bash
cd ~/wsl
./install.sh
```

The install script:
- installs required packages
- configures dotfiles
- creates required directories

## Dotfiles

Configuration files are stored in:

```text
dotfiles/
```

Example:

```text
dotfiles/tmux.conf
```

Installation creates:

```text
~/.tmux.conf -> ~/wsl/dotfiles/tmux.conf
```

Changes made to files inside `dotfiles/` are available immediately through the symlink.

## Projects

The `projects/` directory is used for common projects shared between WSL installations.

Example:

```text
projects/
├── project1/
├── project2/
└── ...
```

## Update repository

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

## Update WSL installation

On another WSL machine:

```bash
./pull.sh
```

This downloads the latest changes:

```bash
git pull
```

## Requirements

- WSL
- Ubuntu/Debian based distribution
- Git
