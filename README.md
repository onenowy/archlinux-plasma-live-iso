# archlinux-plasma-live-iso

Custom Arch Linux live ISOs, built by GitHub Actions from archiso's `releng` profile plus a preset.

## Presets

| Preset | What you get |
| --- | --- |
| `plasma` | Minimal KDE Plasma (Wayland) desktop. Autologin as user `arch` with passwordless sudo, Firefox and the basic KDE apps. |
| `console` | Console-only image. Root `zsh` on every VT through kmscon, no login prompt. CJK text displays through `wqy-microhei`. |

Both presets share:

- UEFI boot only (systemd-boot), with extra boot entries that give the live session 50% of RAM as writable space, load the Nvidia driver early in boot (`modules_load=nvidia_drm`) before the login screen starts, or do both
- EROFS root image with zstd (level 15) compression
- zsh with starship, syntax highlighting and history substring search
- kmscon on tty1, and on tty2-6 when you switch to them, with hardware-accelerated rendering, falling back to the normal getty if it fails
- Nvidia's open kernel driver (`nvidia-open`) for GTX 16xx / RTX 20xx and newer. It blacklists nouveau, so older Nvidia GPUs get no accelerated driver, and nouveau's firmware (`linux-firmware-nvidia`) is left out of the otherwise complete `linux-firmware` set
- NetworkManager (`nmtui` / `nmcli`) instead of systemd-networkd and iwd
- firewalld with the `public` zone set to drop incoming traffic
- No docs, man pages or non-English locales, to keep the image small

## Building

Run the **Arch Live ISO** workflow from the Actions tab and pick a preset. The ISO is published as the release `iso-build-<preset>`, replacing the previous build of that preset. An ISO of 2 GiB or more (GitHub's limit per file) is uploaded as `<iso>.part00`, `<iso>.part01`, … plus `<iso>.sha256`.

The build runs in a privileged `archlinux:latest` container and is not meant to be run on a local machine: `scripts/setup_profile.sh` edits `/etc/pacman.conf` of the system it runs on.

### Joining a split ISO

Download all parts and the `.sha256` file into one folder, then:

```bash
# Linux
cat <iso>.part* > <iso>
sha256sum -c <iso>.sha256
```

```bat
:: Windows (Command Prompt): /b is required, list the parts in order
copy /b <iso>.part00+<iso>.part01 <iso>
certutil -hashfile <iso> SHA256
```

The hash from `certutil` must match the one in `<iso>.sha256`.

## Layout

```
common/                  Files used by every preset
  efiboot/               Extra systemd-boot entries
  firewalld/             Zone overrides, copied to /etc/firewalld
  kmscon/                kmscon.conf
  zsh/, starship.toml    Shell configuration
presets/<name>/
  package_list.x86_64    Packages to install (replaces the releng list)
  profiledef.sh          archiso profile definition
  setup.sh               Picks which setup functions run for this preset
  ...                    Preset-specific config files
scripts/
  setup_profile.sh       Copies releng and applies common/ and the preset
  setup_functions.sh     Functions called from each preset's setup.sh
  create_release.sh      Publishes the ISO as a GitHub release
```

## Adding a preset

1. Create `presets/<name>/` with `package_list.x86_64`, `profiledef.sh` and `setup.sh`.
2. Add `<name>` to the `preset` options in `.github/workflows/build.yml`.
