#!/bin/bash
set -e

# Define Paths
WORK_DIR="/tmp/archlive"
REPO_DIR=$(pwd)
CONFIG_DIR="$REPO_DIR/configs"

echo ">>> Starting Custom Profile Setup..."

# 1. Copy Releng Profile
echo "-> Copying releng profile to $WORK_DIR..."
cp -r /usr/share/archiso/configs/releng "$WORK_DIR"
# [CRITICAL] Grant write permissions for modification
chmod -R +w "$WORK_DIR"

# 2. Apply Custom Package List
if [ -f "$REPO_DIR/package_list.x86_64" ]; then
    echo "-> Applying custom package list..."
    sed 's/#.*//;s/[ \t]*$//;/^$/d' "$REPO_DIR/package_list.x86_64" > "$WORK_DIR/packages.x86_64"
else
    echo "::error::package_list.x86_64 not found!"
    exit 1
fi

# 3. [OPTIMIZE] Remove Docs & Locales
echo "-> Configuring pacman to exclude docs and locales..."
NO_EXTRACT_RULE="NoExtract  = usr/share/help/* usr/share/doc/* usr/share/man/* usr/share/locale/* usr/share/i18n/* !usr/share/locale/en* !usr/share/locale/ko*"
sed -i "/^#NoExtract/c\\$NO_EXTRACT_RULE" /etc/pacman.conf
sed -i "/^#NoExtract/c\\$NO_EXTRACT_RULE" "$WORK_DIR/pacman.conf"

# 4. [INITRAMFS] Optimize Size (Remove KMS & PXE Hooks)
echo "-> Optimizing Initramfs (archiso.conf)..."
CONF_FILE="$WORK_DIR/airootfs/etc/mkinitcpio.conf.d/archiso.conf"
if [ -f "$CONF_FILE" ]; then
    HOOKS_TO_REMOVE=("kms" "archiso_pxe_common" "archiso_pxe_nbd" "archiso_pxe_http" "archiso_pxe_nfs")
    for HOOK in "${HOOKS_TO_REMOVE[@]}"; do
        if grep -q "$HOOK" "$CONF_FILE"; then
            sed -i -E "s/\b$HOOK\b//g" "$CONF_FILE"
        fi
    done
fi

# 5. [NETWORK & DESKTOP] Fix Conflicts & Enable Services
echo "-> Configuring Desktop & Network..."
AIROOTFS_DIR="$WORK_DIR/airootfs"
SYSTEMD_DIR="$AIROOTFS_DIR/etc/systemd/system"
MULTI_USER_DIR="$SYSTEMD_DIR/multi-user.target.wants"

# 5-1. Mask conflicting systemd-networkd services
# This prevents race conditions with NetworkManager
find "$SYSTEMD_DIR" -name "systemd-networkd.service" -delete
find "$SYSTEMD_DIR" -name "systemd-resolved.service" -delete
find "$SYSTEMD_DIR" -name "systemd-networkd.socket" -delete

ln -sf /dev/null "$SYSTEMD_DIR/systemd-networkd.service"
ln -sf /dev/null "$SYSTEMD_DIR/systemd-resolved.service"
ln -sf /dev/null "$SYSTEMD_DIR/systemd-networkd-wait-online.service"

# 5-2. Remove broken resolv.conf symlink
# Essential for NetworkManager to generate a valid DNS config
rm -f "$AIROOTFS_DIR/etc/resolv.conf"

# 5-3. Enable NetworkManager & SDDM
mkdir -p "$MULTI_USER_DIR"
ln -sf /usr/lib/systemd/system/sddm.service "$SYSTEMD_DIR/display-manager.service"
ln -sf /usr/lib/systemd/system/NetworkManager.service "$MULTI_USER_DIR/NetworkManager.service"

# 5-4. SDDM Autologin Config (Copy from external file)
mkdir -p "$AIROOTFS_DIR/etc/sddm.conf.d"
if [ -f "$CONFIG_DIR/autologin.conf" ]; then
    cp "$CONFIG_DIR/autologin.conf" "$AIROOTFS_DIR/etc/sddm.conf.d/autologin.conf"
    chmod 644 "$AIROOTFS_DIR/etc/sddm.conf.d/autologin.conf"
else
    echo "::warning::configs/autologin.conf not found!"
fi

# 6. [USER SETUP] Configure User & Privileges using external files
echo "-> Creating 'arch' user configuration..."

# 6-1. User Creation (sysusers.d)
mkdir -p "$AIROOTFS_DIR/usr/lib/sysusers.d"
if [ -f "$CONFIG_DIR/archiso-user.conf" ]; then
    cp "$CONFIG_DIR/archiso-user.conf" "$AIROOTFS_DIR/usr/lib/sysusers.d/archiso-user.conf"
else
    echo "::error::configs/archiso-user.conf not found!"
    exit 1
fi

# 6-2. Setup Home Directory & Permissions
mkdir -p "$AIROOTFS_DIR/home/arch"
# Append custom permissions to profiledef.sh
if [ -f "$CONFIG_DIR/profiledef_custom.sh" ]; then
    cat "$CONFIG_DIR/profiledef_custom.sh" >> "$WORK_DIR/profiledef.sh"
else
    echo "::warning::configs/profiledef_custom.sh not found! Home dir permissions might be wrong."
fi

# 6-3. Sudoers (CLI) - Passwordless Sudo
mkdir -p "$AIROOTFS_DIR/etc/sudoers.d"
if [ -f "$CONFIG_DIR/00-wheel-nopasswd" ]; then
    cp "$CONFIG_DIR/00-wheel-nopasswd" "$AIROOTFS_DIR/etc/sudoers.d/00-wheel-nopasswd"
    chmod 440 "$AIROOTFS_DIR/etc/sudoers.d/00-wheel-nopasswd"
else
    echo "::warning::configs/00-wheel-nopasswd not found!"
fi

# 6-4. Polkit (GUI) - Passwordless Admin Actions
mkdir -p "$AIROOTFS_DIR/etc/polkit-1/rules.d"
if [ -f "$CONFIG_DIR/49-nopasswd_global.rules" ]; then
    cp "$CONFIG_DIR/49-nopasswd_global.rules" "$AIROOTFS_DIR/etc/polkit-1/rules.d/49-nopasswd_global.rules"
else
    echo "::warning::configs/49-nopasswd_global.rules not found!"
fi

echo ">>> Profile Setup Complete."
