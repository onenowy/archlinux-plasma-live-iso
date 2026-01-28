#!/bin/bash
# Custom preset - KDE Plasma with zsh, starship, fcitx5

source "$REPO_DIR/scripts/setup_functions.sh"

setup_desktop_env
setup_bluetooth
setup_kde_configs
setup_fcitx5 "$AIROOTFS_DIR/home/arch"
setup_zsh_starship
setup_user
