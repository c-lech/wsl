# WSL

Personal WSL environment backup and setup scripts.

## First Installation

On a fresh WSL:

```bash
git clone https://github.com/c-lech/wsl.git ~/wsl
cd ~/wsl
./install.sh

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

## First Installation

On a fresh WSL installation:

    sudo apt update
    sudo apt install -y git
    git clone https://github.com/c-lech/wsl.git ~/wsl
    cd ~/wsl
    ./install.sh


## Install

Run:

    cd ~/wsl
    ./install.sh


The install script:

- installs required packages
- configures dotfiles
- creates required directories


## Dotfiles

Configuration files are stored in:

    dotfiles/

Example:

    dotfiles/tmux.conf


The installation creates:

    ~/.tmux.conf -> ~/wsl/dotfiles/tmux.conf


Changes made to files inside `dotfiles/` are immediately available through the symlink.


## Projects

The `projects/` directory is reserved for common projects shared between WSL installations.


Example:

    projects/
    ├── project1/
    ├── project2/
    └── ...


## Update Repository

After modifying files:

    ./push.sh "update message"


Example:

    ./push.sh "update tmux configuration"


This performs:

    git add .
    git commit -m "update message"
    git push


## Update Local Copy

On another WSL machine:

    ./pull.sh


This performs:

    git pull


## Requirements

- WSL
- Ubuntu/Debian based distribution
- Git
