#!/bin/bash
set -e

# Define Paths
WORK_DIR="/tmp/archlive"
REPO_DIR=$(pwd)

echo ">>> Starting Diet Profile Setup..."

# 1. Copy Releng Profile
echo "-> Copying releng profile to $WORK_DIR..."
cp -r /usr/share/archiso/configs/releng "$WORK_DIR"

# [CRITICAL FIX] Grant write permissions to all copied files
# Files from /usr/share are often read-only, preventing 'sed' from editing them.
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

# [EXACT PATH FIX] Directly target the file used by mkinitcpio-archiso
# Do NOT use 'find' to avoid modifying wrong files.
CONF_FILE="$WORK_DIR/airootfs/etc/mkinitcpio.conf.d/archiso.conf"

if [ -f "$CONF_FILE" ]; then
    echo "   Target config: $CONF_FILE"
    
    # [Debug] Print original HOOKS line (truncated)
    echo "   [Before] $(grep "^HOOKS" "$CONF_FILE" | cut -c 1-80)..."

    # List of hooks to remove
    # Removed 'kms' to save space and 'archiso_pxe_*' for USB-only usage
    HOOKS_TO_REMOVE=(
        "kms" 
        "archiso_pxe_common" 
        "archiso_pxe_nbd" 
        "archiso_pxe_http" 
        "archiso_pxe_nfs"
    )
    
    for HOOK in "${HOOKS_TO_REMOVE[@]}"; do
        # Use -E for extended regex and \b for word boundaries
        if grep -q "$HOOK" "$CONF_FILE"; then
            sed -i -E "s/\b$HOOK\b//g" "$CONF_FILE"
            echo "      - Removed '$HOOK'"
        fi
    done
    
    # [Debug] Print modified HOOKS line to verify
    echo "   [After]  $(grep "^HOOKS" "$CONF_FILE" | cut -c 1-80)..."
else
    echo "::warning::Config file '$CONF_FILE' not found! Initramfs optimization skipped."
    # If using an older profile, check the fallback location
    FALLBACK_CONF="$WORK_DIR/airootfs/etc/mkinitcpio.conf"
    if [ -f "$FALLBACK_CONF" ]; then
        echo "::notice::Found fallback config at $FALLBACK_CONF. Check if optimization is needed manually."
    fi
fi

# 5. Desktop Configuration
echo "-> Configuring Desktop Environment..."
AIROOTFS_DIR="$WORK_DIR/airootfs"

# SDDM Autologin
mkdir -p "$AIROOTFS_DIR/etc/sddm.conf.d"
if [ -f "$REPO_DIR/configs/autologin.conf" ]; then
    echo "   Applying autologin config..."
    cp "$REPO_DIR/configs/autologin.conf" "$AIROOTFS_DIR/etc/sddm.conf.d/autologin.conf"
    chmod 644 "$AIROOTFS_DIR/etc/sddm.conf.d/autologin.conf"
else
    echo "::warning::configs/autologin.conf not found!"
fi

# Enable Essential Services
SYSTEMD_DIR="$AIROOTFS_DIR/etc/systemd/system"
mkdir -p "$SYSTEMD_DIR/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/sddm.service "$SYSTEMD_DIR/display-manager.service"
ln -sf /usr/lib/systemd/system/NetworkManager.service "$SYSTEMD_DIR/multi-user.target.wants/NetworkManager.service"

# 6. [USER SETUP] Create 'arch' user for Autologin
echo "-> Creating 'arch' user configuration..."

# 6-1. Use systemd-sysusers
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

# 6-2. Create Home Directory & Permissions
mkdir -p "$AIROOTFS_DIR/home/arch"
cat <<EOF >> "$WORK_DIR/profiledef.sh"
file_permissions+=(["/home/arch"]="1000:1000:755")
EOF

# 6-3. Enable Passwordless Sudo
mkdir -p "$AIROOTFS_DIR/etc/sudoers.d"
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > "$AIROOTFS_DIR/etc/sudoers.d/00-wheel-nopasswd"
chmod 440 "$AIROOTFS_DIR/etc/sudoers.d/00-wheel-nopasswd"

echo ">>> Profile Setup Complete."
