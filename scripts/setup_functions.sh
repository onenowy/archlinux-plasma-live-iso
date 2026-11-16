#!/bin/bash
# Shared setup functions for presets

# ZSH & Starship configuration (shared by all presets)
setup_zsh_starship() {
    echo "-> Configuring ZSH & Starship..."
    mkdir -p "$AIROOTFS_DIR/etc/zsh"
    cp "$COMMON_DIR/zsh/"* "$AIROOTFS_DIR/etc/zsh/"
    cp "$COMMON_DIR/starship.toml" "$AIROOTFS_DIR/etc/starship.toml"
}

# Desktop environment (Plasma Login Manager)
setup_desktop_env() {
    echo "-> Configuring Desktop Environment..."
    ln -sf /usr/lib/systemd/system/plasmalogin.service "$SYSTEMD_DIR/display-manager.service"

    if [ -f "$PRESET_DIR/autologin.conf" ]; then
        mkdir -p "$AIROOTFS_DIR/etc/plasmalogin.conf.d"
        cp "$PRESET_DIR/autologin.conf" "$AIROOTFS_DIR/etc/plasmalogin.conf.d/autologin.conf"
    fi
}

# User account setup (arch user, sudoers, polkit)
setup_user() {
    echo "-> Configuring User & Permissions..."
    mkdir -p "$AIROOTFS_DIR/usr/lib/sysusers.d"
    [ -f "$PRESET_DIR/archiso-user.conf" ] && cp "$PRESET_DIR/archiso-user.conf" "$AIROOTFS_DIR/usr/lib/sysusers.d/archiso-user.conf"

    mkdir -p "$AIROOTFS_DIR/home/arch"

    mkdir -p "$AIROOTFS_DIR/etc/sudoers.d"
    [ -f "$PRESET_DIR/00-wheel-nopasswd" ] && cp "$PRESET_DIR/00-wheel-nopasswd" "$AIROOTFS_DIR/etc/sudoers.d/00-wheel-nopasswd" && chmod 440 "$AIROOTFS_DIR/etc/sudoers.d/00-wheel-nopasswd"

    mkdir -p "$AIROOTFS_DIR/etc/polkit-1/rules.d"
    [ -f "$PRESET_DIR/49-nopasswd_global.rules" ] && cp "$PRESET_DIR/49-nopasswd_global.rules" "$AIROOTFS_DIR/etc/polkit-1/rules.d/49-nopasswd_global.rules"
}

# KDE configs (kwallet)
setup_kde_configs() {
    mkdir -p "$AIROOTFS_DIR/home/arch/.config"

    if [ -f "$PRESET_DIR/kwalletrc" ]; then
        cp "$PRESET_DIR/kwalletrc" "$AIROOTFS_DIR/home/arch/.config/kwalletrc"
    fi
}

# Bluetooth service
setup_bluetooth() {
    echo "-> Enabling Bluetooth..."
    ln -sf /usr/lib/systemd/system/bluetooth.service "$MULTI_USER_DIR/bluetooth.service"
}

# kmscon setup (shared config from common/)
# $1 (optional): command kmscon starts instead of the default /bin/login,
#                e.g. "/usr/bin/zsh --login" for a root shell without a login prompt
setup_kmscon() {
    local login_cmd="${1:-}"

    echo "-> Configuring kmscon..."
    mkdir -p "$AIROOTFS_DIR/etc/kmscon"
    cp "$COMMON_DIR/kmscon/"* "$AIROOTFS_DIR/etc/kmscon/"
    if [ -n "$login_cmd" ]; then
        printf '\nlogin=%s\n' "$login_cmd" >> "$AIROOTFS_DIR/etc/kmscon/kmscon.conf"
    fi

    # Enable kmscon on tty1-6. kmsconvt@ conflicts with getty@ on the same VT
    # and starts it as a fallback if kmscon fails.
    mkdir -p "$SYSTEMD_DIR/getty.target.wants"
    for i in {1..6}; do
        ln -sf /usr/lib/systemd/system/kmsconvt@.service "$SYSTEMD_DIR/getty.target.wants/kmsconvt@tty${i}.service"
    done

    # Use kmscon for dynamically allocated VTs as well
    ln -sf /usr/lib/systemd/system/kmsconvt@.service "$SYSTEMD_DIR/autovt@.service"

    # plasmalogin.service already ships Conflicts=/After=kmsconvt@tty1.service,
    # so no drop-in is needed for the display manager.
}
