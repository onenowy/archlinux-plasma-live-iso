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

# Root console setup (zsh shell, remove automated scripts)
setup_root_console() {
    echo "-> Configuring root for console..."
    sed -i -E 's|^(root:x:0:0:root:/root:)(/usr)?/bin/bash|\1/usr/bin/zsh|' "$AIROOTFS_DIR/etc/passwd"

    # Copy PAM configurations if they exist in the preset
    if [ -d "$PRESET_DIR/pam.d" ]; then
        mkdir -p "$AIROOTFS_DIR/etc/pam.d"
        cp -r "$PRESET_DIR/pam.d/"* "$AIROOTFS_DIR/etc/pam.d/"
    fi
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

# Bluetooth service
setup_bluetooth() {
    echo "-> Enabling Bluetooth..."
    ln -sf /usr/lib/systemd/system/bluetooth.service "$MULTI_USER_DIR/bluetooth.service"
}

# kmscon setup
setup_kmscon() {
    if [ -d "$PRESET_DIR/kmscon" ]; then
        echo "-> Configuring kmscon..."
        mkdir -p "$AIROOTFS_DIR/etc/kmscon"
        cp "$PRESET_DIR/kmscon/"* "$AIROOTFS_DIR/etc/kmscon/"

        mkdir -p "$SYSTEMD_DIR/getty.target.wants"

        # Enable kmscon on tty1
        ln -sf /dev/null "$SYSTEMD_DIR/getty@tty1.service"
        ln -sf /usr/lib/systemd/system/kmsconvt@.service "$SYSTEMD_DIR/getty.target.wants/kmsconvt@tty1.service"

        # Enable kmscon for dynamically allocated VTs (tty2-6)
        ln -sf /usr/lib/systemd/system/kmsconvt@.service "$SYSTEMD_DIR/autovt@.service"

        if [ -f "$PRESET_DIR/systemd/kmsconvt-autologin.conf" ]; then
            mkdir -p "$SYSTEMD_DIR/kmsconvt@tty1.service.d"
            cp "$PRESET_DIR/systemd/kmsconvt-autologin.conf" "$SYSTEMD_DIR/kmsconvt@tty1.service.d/autologin.conf"
        fi

        # If display manager is used, ensure it conflicts with and runs after kmsconvt@tty1.service
        if [ "$PRESET" = "plasma" ]; then
            echo "-> Configuring display manager to conflict with and run after kmsconvt@tty1.service..."
            mkdir -p "$SYSTEMD_DIR/plasmalogin.service.d"
            cat <<EOF > "$SYSTEMD_DIR/plasmalogin.service.d/override.conf"
[Unit]
Conflicts=kmsconvt@tty1.service
After=kmsconvt@tty1.service
EOF
        fi
    fi
}