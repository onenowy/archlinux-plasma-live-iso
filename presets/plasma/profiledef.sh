#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="archlinux-plasma"
iso_label="ARCH_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Arch Linux Plasma"
iso_application="Arch Linux Plasma Live"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('uefi.systemd-boot')
pacman_conf="pacman.conf"

# [EROFS Configuration]
# -zzstd,level=15: zstd level 15. About 10% bigger than LZMA, but compresses
#   about 2x faster and decompresses about 9x faster. Higher zstd levels save
#   ~1.5% for ~6x the build time; LZMA levels above 6 gain nothing with 1 MiB
#   pclusters, since the larger dictionaries never fit in one pcluster.
# -C 1048576: 1MB Pcluster size
# -E ...: Enable ztailpacking, merge all fragments, inode-based deduplication
airootfs_image_type="erofs"
airootfs_image_tool_options=('-zzstd,level=15' '-C' '1048576' '-E' 'ztailpacking,all-fragments,fragdedupe=inode')

# Bootstrap compression settings
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')

# File Permissions (Merged /home/arch here)
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.gnupg"]="0:0:700"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/home/arch"]="1000:1000:755"
  ["/home/arch/.config"]="1000:1000:755"
  ["/home/arch/.config/kwalletrc"]="1000:1000:644"
)
