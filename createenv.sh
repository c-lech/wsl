#!/bin/bash

set -euo pipefail

#VAGRANT_DIR="/mnt/c/Users/benito/vagrant"
VAGRANT_DIR="/home/benito/projects/infra/vagrant"

environments=(
  zbxserver
  zbxproxy
)

section() {
  echo
  echo "================================================"
  echo
  echo "  $1"
}

item() {
  echo
  echo "================================================"
  echo
  echo "  $1"
  echo
}

step() {
  echo "  -> $1"
}

section "Creating development environments"

for env in "${environments[@]}"; do
  item "$env"
  step "Destroying old VM"
  (cd "$VAGRANT_DIR/$env" && vagrant destroy -f)
  step "Starting VM"
  (cd "$VAGRANT_DIR/$env" && vagrant up)
  step "Done"
done

item "Setup complete"
step "All environments ready"
