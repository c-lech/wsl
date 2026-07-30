#!/bin/bash

set -e

sudo apt update
sudo apt install -y git

git clone https://github.com/c-lech/wsl.git ~/wsl

cd ~/wsl
./install.sh
