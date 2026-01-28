#!/bin/bash
set -eu

export REPO_DIR=$(pwd)
export PRESET=${PRESET:-plasma}
export PRESET_DIR="$REPO_DIR/presets/$PRESET"

echo ">>> Starting Profile Setup for preset: $PRESET"
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
    HOOKS_TO_REMOVE=("kms" "memdisk" "archiso_pxe_common" "archiso_pxe_nbd" "archiso_pxe_http" "archiso_pxe_nfs")
    for HOOK in "${HOOKS_TO_REMOVE[@]}"; do
        if grep -q "$HOOK" "$CONF_FILE"; then
            sed -i -E "s/\b$HOOK\b//g" "$CONF_FILE"
        fi
    done
fi

# Export common directories for preset scripts
export AIROOTFS_DIR="$BUILD_DIR/airootfs"
export SYSTEMD_DIR="$AIROOTFS_DIR/etc/systemd/system"
export MULTI_USER_DIR="$SYSTEMD_DIR/multi-user.target.wants"

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

# Firewalld Configuration (if exists in preset)
if [ -d "$PRESET_DIR/firewalld" ]; then
    echo "-> Configuring Firewalld..."
    mkdir -p "$AIROOTFS_DIR/etc/firewalld"
    cp -r "$PRESET_DIR/firewalld/"* "$AIROOTFS_DIR/etc/firewalld/"
    chmod -R u=rwX,g=rX,o=rX "$AIROOTFS_DIR/etc/firewalld"
    ln -sf /usr/lib/systemd/system/firewalld.service "$MULTI_USER_DIR/firewalld.service"
fi

# Run preset-specific setup
if [ -f "$PRESET_DIR/setup.sh" ]; then
    echo "-> Running preset-specific setup..."
    source "$PRESET_DIR/setup.sh"
else
    echo "::warning::No setup.sh found in preset, skipping preset-specific setup"
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

echo ">>> Profile Setup Complete for preset: $PRESET"
