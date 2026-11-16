#!/bin/bash
# Console preset - Minimal console with zsh, starship, kmscon

source "$REPO_DIR/scripts/setup_functions.sh"

setup_zsh_starship
# Root zsh directly on every VT, no login prompt
setup_kmscon "/usr/bin/zsh --login"
setup_bluetooth
