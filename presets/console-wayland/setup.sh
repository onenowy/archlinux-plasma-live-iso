#!/bin/bash
# Console-Wayland preset - Wayland console with cage, foot, zsh, fcitx5

source "$REPO_DIR/scripts/setup_functions.sh"

setup_zsh_starship
setup_root_console
setup_cage_foot
setup_fcitx5 "$AIROOTFS_DIR/root"
