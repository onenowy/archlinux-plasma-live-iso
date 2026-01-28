#!/bin/bash
# Custom preset - KDE Plasma with zsh, starship

source "$REPO_DIR/scripts/setup_functions.sh"

setup_desktop_env
setup_kde_configs
setup_zsh_starship
setup_user