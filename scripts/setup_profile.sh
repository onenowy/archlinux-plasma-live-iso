#!/bin/bash
set -eu

REPO_DIR=$(pwd)
PRESET_DIR="$REPO_DIR/presets/${PRESET:-plasma}"

echo ">>> Starting Profile Setup for preset: ${PRESET:-plasma}"
echo "-> Working Target: $BUILD_DIR"
echo "-> Preset Directory: $PRESET_DIR"

# Validate preset exists
if [ ! -d "$PRESET_DIR" ]; then
    echo "::error::Preset directory not found: $PRESET_DIR"
    exit 1
fi

# Copy Base Profile (releng)
echo "-> Copying releng profile..."
cp -r /usr/share/archiso/configs/releng "$BUILD_DIR"
chmod -R +w "$BUILD_DIR"

# Apply Custom Packages
if [ -f "$PRESET_DIR/package_list.x86_64" ]; then
    echo "-> Applying custom package list..."
    sed 's/#.*//;s/[ \t]*$//;/^$/d' "$PRESET_DIR/package_list.x86_64" > "$BUILD_DIR/packages.x86_64"
else
    echo "::error::package_list.x86_64 not found in preset!"
    exit 1
fi

# Pacman Config (Exclude Docs/Locales)
echo "-> Configuring pacman exclusions..."
NO_EXTRACT_RULE="NoExtract  = usr/share/help/* usr/share/doc/* usr/share/man/* usr/share/locale/* usr/share/i18n/* !usr/share/locale/en*"
sed -i "s|^#NoExtract.*|${NO_EXTRACT_RULE}|" /etc/pacman.conf
sed -i "s|^#NoExtract.*|${NO_EXTRACT_RULE}|" "$BUILD_DIR/pacman.conf"

# Remove "with speech" boot entries
echo "-> Removing speech accessibility boot entries..."
rm -f "$BUILD_DIR"/efiboot/loader/entries/*speech*.conf

# Add custom boot entries (if exists)
if [ -d "$PRESET_DIR/efiboot/loader/entries" ]; then
    echo "-> Adding custom boot entries..."
    cp "$PRESET_DIR"/efiboot/loader/entries/*.conf "$BUILD_DIR/efiboot/loader/entries/"
fi

# Initramfs Optimization (Remove KMS/PXE hooks)
echo "-> Optimizing Initramfs..."
CONF_FILE="$BUILD_DIR/airootfs/etc/mkinitcpio.conf.d/archiso.conf"
if [ -f "$CONF_FILE" ]; then
    HOOKS_TO_REMOVE=("kms" "archiso_pxe_common" "archiso_pxe_nbd" "archiso_pxe_http" "archiso_pxe_nfs")
    for HOOK in "${HOOKS_TO_REMOVE[@]}"; do
        if grep -q "$HOOK" "$CONF_FILE"; then
            sed -i -E "s/\b$HOOK\b//g" "$CONF_FILE"
        fi
    done
fi

# Common Setup
AIROOTFS_DIR="$BUILD_DIR/airootfs"
SYSTEMD_DIR="$AIROOTFS_DIR/etc/systemd/system"
MULTI_USER_DIR="$SYSTEMD_DIR/multi-user.target.wants"

# Network Configuration (common for all presets)
echo "-> Configuring Network..."
find "$SYSTEMD_DIR" -name "systemd-networkd.service" -delete
find "$SYSTEMD_DIR" -name "systemd-resolved.service" -delete
find "$SYSTEMD_DIR" -name "systemd-networkd.socket" -delete
ln -sf /dev/null "$SYSTEMD_DIR/systemd-networkd.service"
ln -sf /dev/null "$SYSTEMD_DIR/systemd-resolved.service"
ln -sf /dev/null "$SYSTEMD_DIR/systemd-networkd-wait-online.service"
rm -f "$AIROOTFS_DIR/etc/resolv.conf"

mkdir -p "$MULTI_USER_DIR"
ln -sf /usr/lib/systemd/system/NetworkManager.service "$MULTI_USER_DIR/NetworkManager.service"

# Firewalld Configuration (common for all presets)
if [ -d "$PRESET_DIR/firewalld" ]; then
    echo "-> Configuring Firewalld..."
    mkdir -p "$AIROOTFS_DIR/etc/firewalld"
    cp -r "$PRESET_DIR/firewalld/"* "$AIROOTFS_DIR/etc/firewalld/"
    chmod -R u=rwX,g=rX,o=rX "$AIROOTFS_DIR/etc/firewalld"
    ln -sf /usr/lib/systemd/system/firewalld.service "$MULTI_USER_DIR/firewalld.service"
fi

# Desktop Environment Setup (plasma, custom only)
if [ "${PRESET:-plasma}" != "console" ]; then
    echo "-> Configuring Desktop Environment..."
    ln -sf /usr/lib/systemd/system/sddm.service "$SYSTEMD_DIR/display-manager.service"
    ln -sf /usr/lib/systemd/system/bluetooth.service "$MULTI_USER_DIR/bluetooth.service"

    # Apply SDDM Autologin
    if [ -f "$PRESET_DIR/autologin.conf" ]; then
        mkdir -p "$AIROOTFS_DIR/etc/sddm.conf.d"
        cp "$PRESET_DIR/autologin.conf" "$AIROOTFS_DIR/etc/sddm.conf.d/autologin.conf"
    fi

    # KWallet Configuration
    if [ -f "$PRESET_DIR/kwalletrc" ]; then
        mkdir -p "$AIROOTFS_DIR/home/arch/.config"
        cp "$PRESET_DIR/kwalletrc" "$AIROOTFS_DIR/home/arch/.config/kwalletrc"
    fi
fi

# Console preset: enable services without GUI
if [ "${PRESET:-plasma}" = "console" ]; then
    echo "-> Configuring Console Environment..."
    ln -sf /usr/lib/systemd/system/sshd.service "$MULTI_USER_DIR/sshd.service"
fi

# ZSH & Starship Configuration (custom, console only)
if [ "${PRESET:-plasma}" = "custom" ] || [ "${PRESET:-plasma}" = "console" ]; then
    echo "-> Configuring ZSH & Starship..."
    if [ -d "$PRESET_DIR/zsh" ]; then
        mkdir -p "$AIROOTFS_DIR/etc/zsh"
        cp "$PRESET_DIR/zsh/"* "$AIROOTFS_DIR/etc/zsh/"
    fi
    if [ -f "$PRESET_DIR/starship.toml" ]; then
        cp "$PRESET_DIR/starship.toml" "$AIROOTFS_DIR/etc/starship.toml"
    fi
fi

# User Setup (plasma, custom only - console uses root)
if [ "${PRESET:-plasma}" != "console" ]; then
    echo "-> Configuring User & Permissions..."
    mkdir -p "$AIROOTFS_DIR/usr/lib/sysusers.d"
    [ -f "$PRESET_DIR/archiso-user.conf" ] && cp "$PRESET_DIR/archiso-user.conf" "$AIROOTFS_DIR/usr/lib/sysusers.d/archiso-user.conf"

    mkdir -p "$AIROOTFS_DIR/home/arch"

    mkdir -p "$AIROOTFS_DIR/etc/sudoers.d"
    [ -f "$PRESET_DIR/00-wheel-nopasswd" ] && cp "$PRESET_DIR/00-wheel-nopasswd" "$AIROOTFS_DIR/etc/sudoers.d/00-wheel-nopasswd" && chmod 440 "$AIROOTFS_DIR/etc/sudoers.d/00-wheel-nopasswd"

    mkdir -p "$AIROOTFS_DIR/etc/polkit-1/rules.d"
    [ -f "$PRESET_DIR/49-nopasswd_global.rules" ] && cp "$PRESET_DIR/49-nopasswd_global.rules" "$AIROOTFS_DIR/etc/polkit-1/rules.d/49-nopasswd_global.rules"
else
    # Console: Set root shell to zsh
    echo "-> Configuring root shell to zsh..."
    sed -i 's|^root:x:0:0:root:/root:/usr/bin/bash|root:x:0:0:root:/root:/usr/bin/zsh|' "$AIROOTFS_DIR/etc/passwd"
fi

# Apply Custom Profile Definition
echo "-> Overwriting profiledef.sh..."
if [ -f "$PRESET_DIR/profiledef.sh" ]; then
    cp "$PRESET_DIR/profiledef.sh" "$BUILD_DIR/profiledef.sh"
    chmod +x "$BUILD_DIR/profiledef.sh"
else
    echo "::error::profiledef.sh not found in preset!"
    exit 1
fi

echo ">>> Profile Setup Complete for preset: ${PRESET:-plasma}"
