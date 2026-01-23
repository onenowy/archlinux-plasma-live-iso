#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="archlinux-console"
iso_label="ARCH_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Arch Linux Console"
iso_application="Arch Linux Console Live"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('uefi.systemd-boot')
pacman_conf="pacman.conf"

# [EROFS Configuration]
airootfs_image_type="erofs"
airootfs_image_tool_options=('-zlzma,6' '-C' '1048576' '-E' 'ztailpacking,all-fragments,fragdedupe=inode')

# Bootstrap compression settings
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')

# File Permissions
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.gnupg"]="0:0:700"
  ["/home/arch"]="1000:1000:755"
)
