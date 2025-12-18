#!/bin/bash
set -e

# Define Paths
WORK_DIR="/tmp/archlive"
REPO_DIR=$(pwd)

echo ">>> Starting Diet Profile Setup..."

# 1. Copy Releng Profile
echo "-> Copying releng profile to $WORK_DIR..."
cp -r /usr/share/archiso/configs/releng "$WORK_DIR"

# [CRITICAL] Grant write permissions
chmod -R +w "$WORK_DIR"

# 2. Apply Custom Package List
if [ -f "$REPO_DIR/package_list.x86_64" ]; then
    echo "-> Applying custom package list..."
    sed 's/#.*//;s/[ \t]*$//;/^$/d' "$REPO_DIR/package_list.x86_64" > "$WORK_DIR/packages.x86_64"
else
    echo "::error::package_list.x86_64 not found!"
    exit 1
fi

# 3. [DIET] Remove Docs & Locales via pacman.conf
echo "-> Configuring pacman to exclude docs and locales..."
NO_EXTRACT_RULE="NoExtract  = usr/share/help/* usr/share/doc/* usr/share/man/* usr/share/locale/* usr/share/i18n/* !usr/share/locale/en* !usr/share/locale/ko*"
sed -i "/^#NoExtract/c\\$NO_EXTRACT_RULE" /etc/pacman.conf
sed -i "/^#NoExtract/c\\$NO_EXTRACT_RULE" "$WORK_DIR/pacman.conf"

# 4. [INITRAMFS] Optimize Size (Target: archiso.conf)
echo "-> Optimizing Initramfs (archiso.conf)..."
CONF_FILE="$WORK_DIR/airootfs/etc/mkinitcpio.conf.d/archiso.conf"

if [ -f "$CONF_FILE" ]; then
    echo "   Target config: $CONF_FILE"
    # Remove 'kms' and 'pxe' hooks
    HOOKS_TO_REMOVE=("kms" "archiso_pxe_common" "archiso_pxe_nbd" "archiso_pxe_http" "archiso_pxe_nfs")
    for HOOK in "${HOOKS_TO_REMOVE[@]}"; do
        if grep -q "$HOOK" "$CONF_FILE"; then
            sed -i -E "s/\b$HOOK\b//g" "$CONF_FILE"
            echo "      - Removed '$HOOK'"
        fi
    done
else
    echo "::warning::Config file '$CONF_FILE' not found! Initramfs optimization skipped."
fi

# 5. Desktop & Network Configuration
echo "-> Configuring Desktop & Network..."
AIROOTFS_DIR="$WORK_DIR/airootfs"
SYSTEMD_DIR="$AIROOTFS_DIR/etc/systemd/system"
MULTI_USER_DIR="$SYSTEMD_DIR/multi-user.target.wants"

# 5-1. [FIX] Mask conflicting systemd-networkd services
# We must use masking (/dev/null symlink) to prevent them from starting by socket activation.
echo "   Masking systemd-networkd & resolved..."

# Remove existing enable symlinks first
find "$SYSTEMD_DIR" -name "systemd-networkd.service" -delete
find "$SYSTEMD_DIR" -name "systemd-resolved.service" -delete
find "$SYSTEMD_DIR" -name "systemd-networkd.socket" -delete

# Create mask symlinks (Strong disable)
ln -sf /dev/null "$SYSTEMD_DIR/systemd-networkd.service"
ln -sf /dev/null "$SYSTEMD_DIR/systemd-resolved.service"
ln -sf /dev/null "$SYSTEMD_DIR/systemd-networkd.socket"
ln -sf /dev/null "$SYSTEMD_DIR/systemd-networkd-wait-online.service"

# 5-2. [FIX] Remove broken resolv.conf symlink
# releng points /etc/resolv.conf to systemd-resolved by default.
# Since we masked resolved, this link is dead. We must remove it so NetworkManager can generate a new one.
echo "   Fixing DNS configuration..."
rm -f "$AIROOTFS_DIR/etc/resolv.conf"

# 5-3. Enable NetworkManager & SDDM
echo "   Enabling NetworkManager & SDDM..."
mkdir -p "$MULTI_USER_DIR"
ln -sf /usr/lib/systemd/system/sddm.service "$SYSTEMD_DIR/display-manager.service"
ln -sf /usr/lib/systemd/system/NetworkManager.service "$MULTI_USER_DIR/NetworkManager.service"

# 5-4. Apply SDDM Autologin Config
mkdir -p "$AIROOTFS_DIR/etc/sddm.conf.d"
if [ -f "$REPO_DIR/configs/autologin.conf" ]; then
    cp "$REPO_DIR/configs/autologin.conf" "$AIROOTFS_DIR/etc/sddm.conf.d/autologin.conf"
    chmod 644 "$AIROOTFS_DIR/etc/sddm.conf.d/autologin.conf"
fi

# 6. [USER SETUP] Create 'arch' user for Autologin
echo "-> Creating 'arch' user configuration..."

mkdir -p "$AIROOTFS_DIR/usr/lib/sysusers.d"
cat <<EOF > "$AIROOTFS_DIR/usr/lib/sysusers.d/archiso-user.conf"
u arch 1000 "Arch Live User" /home/arch /bin/bash
m arch wheel
m arch video
m arch audio
m arch storage
m arch optical
m arch network
m arch power
EOF

mkdir -p "$AIROOTFS_DIR/home/arch"
cat <<EOF >> "$WORK_DIR/profiledef.sh"
file_permissions+=(["/home/arch"]="1000:1000:755")
EOF

mkdir -p "$AIROOTFS_DIR/etc/sudoers.d"
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > "$AIROOTFS_DIR/etc/sudoers.d/00-wheel-nopasswd"
chmod 440 "$AIROOTFS_DIR/etc/sudoers.d/00-wheel-nopasswd"

echo ">>> Profile Setup Complete."
