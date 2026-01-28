#!/bin/bash
# Shared setup functions for presets

# ZSH & Starship configuration
setup_zsh_starship() {
    echo "-> Configuring ZSH & Starship..."
    if [ -d "$PRESET_DIR/zsh" ]; then
        mkdir -p "$AIROOTFS_DIR/etc/zsh"
        cp "$PRESET_DIR/zsh/"* "$AIROOTFS_DIR/etc/zsh/"
    fi
    if [ -f "$PRESET_DIR/starship.toml" ]; then
        cp "$PRESET_DIR/starship.toml" "$AIROOTFS_DIR/etc/starship.toml"
    fi
}

# Desktop environment (SDDM + Bluetooth)
setup_desktop_env() {
    echo "-> Configuring Desktop Environment..."
    ln -sf /usr/lib/systemd/system/sddm.service "$SYSTEMD_DIR/display-manager.service"
    ln -sf /usr/lib/systemd/system/bluetooth.service "$MULTI_USER_DIR/bluetooth.service"

    if [ -f "$PRESET_DIR/autologin.conf" ]; then
        mkdir -p "$AIROOTFS_DIR/etc/sddm.conf.d"
        cp "$PRESET_DIR/autologin.conf" "$AIROOTFS_DIR/etc/sddm.conf.d/autologin.conf"
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

# Root console setup (zsh shell, remove automated scripts)
setup_root_console() {
    echo "-> Configuring root for console..."
    sed -i 's|^root:x:0:0:root:/root:/usr/bin/bash|root:x:0:0:root:/root:/usr/bin/zsh|' "$AIROOTFS_DIR/etc/passwd"
    rm -f "$AIROOTFS_DIR/root/.zlogin" "$AIROOTFS_DIR/root/.automated_script.sh"
}

# KDE configs (kwallet, kwin, kxkb)
setup_kde_configs() {
    mkdir -p "$AIROOTFS_DIR/home/arch/.config"

    if [ -f "$PRESET_DIR/kwalletrc" ]; then
        cp "$PRESET_DIR/kwalletrc" "$AIROOTFS_DIR/home/arch/.config/kwalletrc"
    fi
    if [ -f "$PRESET_DIR/kwinrc" ]; then
        cp "$PRESET_DIR/kwinrc" "$AIROOTFS_DIR/home/arch/.config/kwinrc"
    fi
    if [ -f "$PRESET_DIR/kxkbrc" ]; then
        cp "$PRESET_DIR/kxkbrc" "$AIROOTFS_DIR/home/arch/.config/kxkbrc"
    fi
}

# kmscon setup
setup_kmscon() {
    if [ -d "$PRESET_DIR/kmscon" ]; then
        echo "-> Configuring kmscon..."
        mkdir -p "$AIROOTFS_DIR/etc/kmscon"
        cp "$PRESET_DIR/kmscon/"* "$AIROOTFS_DIR/etc/kmscon/"

        mkdir -p "$SYSTEMD_DIR/getty.target.wants"
        ln -sf /dev/null "$SYSTEMD_DIR/getty@tty1.service"
        ln -sf /usr/lib/systemd/system/kmsconvt@.service "$SYSTEMD_DIR/getty.target.wants/kmsconvt@tty1.service"

        if [ -f "$PRESET_DIR/systemd/kmsconvt-autologin.conf" ]; then
            mkdir -p "$SYSTEMD_DIR/kmsconvt@tty1.service.d"
            cp "$PRESET_DIR/systemd/kmsconvt-autologin.conf" "$SYSTEMD_DIR/kmsconvt@tty1.service.d/autologin.conf"
        fi
    fi
}