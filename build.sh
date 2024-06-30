#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091 # do not warn for external scripts
set -Eeuo pipefail

BOOTABLE_PROJECT_ROOT="$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)"
BOOTABLE_PLUGINS_DIR="${BOOTABLE_PROJECT_ROOT}/scripts"
. "${BOOTABLE_PLUGINS_DIR}/config.sh"
. "${BOOTABLE_PLUGINS_DIR}/common.sh"
. "${BOOTABLE_PLUGINS_DIR}/plugin-ui-require-root.sh"

# Load user config
# We should do this as early as possible
BOOTABLE_BUILD_CONFIG_DIR="$1"
>&2 printf "[*] Using config %s\n" "${BOOTABLE_BUILD_CONFIG_DIR}"
bootable::util::source "${BOOTABLE_BUILD_CONFIG_DIR}/config.sh"
bootable::util::invoke_hook "user::config_load::post"

# Create temporary directory
BOOTABLE_TMP_NAME="$(bootable::util::random_string 12)"
BOOTABLE_SCOPED_TMP_DIR="${BOOTABLE_GLOBAL_TMP_DIR}/${BOOTABLE_TMP_NAME}"
>&2 printf "[i] Building into temporary directory %s\n" "${BOOTABLE_SCOPED_TMP_DIR}"
mkdir -p "${BOOTABLE_SCOPED_TMP_DIR}"

# Create version info stamp file
bootable::util::release_file > "${BOOTABLE_SCOPED_TMP_DIR}/bootable-release"

# Build the OS image
BOOTABLE_BUILD_IMAGE_TAG="${BOOTABLE_TEMP_TAG_PREFIX}${BOOTABLE_TMP_NAME}"
bootable::container::build::image "${BOOTABLE_BUILD_CONFIG_DIR}" "${BOOTABLE_BUILD_CONFIG_DIR}/Containerfile" "${BOOTABLE_BUILD_IMAGE_TAG}"
bootable::container::export::tar "${BOOTABLE_BUILD_IMAGE_TAG}" "${BOOTABLE_SCOPED_TMP_DIR}/rootfs.tar"
# Load plugins
case "$(bootable::container::label::get "${BOOTABLE_BUILD_IMAGE_TAG}" "bootable.plugin.bootloader" "grub2")" in
    grub0)
    bootable::util::load_plugin "${BOOTABLE_BUILD_CONFIG_DIR}" "bootloader-grub0"
    ;;

    grub2)
    bootable::util::load_plugin "${BOOTABLE_BUILD_CONFIG_DIR}" "bootloader-grub2"
    ;;

    *)
    >&2 printf "Unknown bootloader type\n"
    exit 1
    ;;
esac
case "$(bootable::container::label::get "${BOOTABLE_BUILD_IMAGE_TAG}" "bootable.plugin.partition" "gpt")" in
    gpt)
    bootable::util::load_plugin "${BOOTABLE_BUILD_CONFIG_DIR}" "partition-gpt"
    ;;

    mbr)
    bootable::util::load_plugin "${BOOTABLE_BUILD_CONFIG_DIR}" "partition-mbr"
    ;;

    *)
    >&2 printf "Unknown partition type\n"
    exit 1
    ;;
esac
case "$(bootable::container::label::get "${BOOTABLE_BUILD_IMAGE_TAG}" "bootable.plugin.initrd" "")" in
    dracut)
    bootable::util::load_plugin "${BOOTABLE_BUILD_CONFIG_DIR}" "initrd-dracut"
    ;;

    initramfs-tools)
    bootable::util::load_plugin "${BOOTABLE_BUILD_CONFIG_DIR}" "initrd-initramfs-tools"
    ;;

    mkinitcpio)
    bootable::util::load_plugin "${BOOTABLE_BUILD_CONFIG_DIR}" "initrd-mkinitcpio"
    ;;

    mkinitfs)
    bootable::util::load_plugin "${BOOTABLE_BUILD_CONFIG_DIR}" "initrd-mkinitfs"
    ;;

    *)
    >&2 printf "Unknown initrd type\n"
    exit 1
    ;;
esac

# Create and partition the disk (offline)
>&2 printf "[*] Creating the boot disk...\n"
rm -f -- "${BOOTABLE_SCOPED_TMP_DIR}/boot.img"
bootable::toolchain fallocate -l "${BOOTABLE_DISK_SIZE}" "${BOOTABLE_SCOPED_TMP_DIR}/boot.img"
# Note: roughly follows the discoverable partitions specification while compatible with both EFI and legacy boot
bootable::plugin::disk::create "${BOOTABLE_SCOPED_TMP_DIR}/boot.img"

# Online the disk
>&2 printf "[*] Attaching the boot disk...\n"
BOOTABLE_DISK_LOOPBACK_DEVICE="$(bootable::toolchain losetup --find --show "${BOOTABLE_SCOPED_TMP_DIR}/boot.img")"
bootable::toolchain partprobe "${BOOTABLE_DISK_LOOPBACK_DEVICE}" \
    || bootable::toolchain kpartx -u "${BOOTABLE_DISK_LOOPBACK_DEVICE}" \
    || >&2 printf "[-] Unable to refresh partition layout!\n"
if command -v udevadm >/dev/null; then
    >&2 printf "[+] Waiting for hotplug events...\n"
    udevadm settle --timeout=10
else
    >&2 printf "[-] Udev not found\n"
    sleep 10
fi

# Format all partitions
BOOTABLE_MOUNT_ROOT="${BOOTABLE_SCOPED_TMP_DIR}/new_root"
umount --recursive --verbose "${BOOTABLE_MOUNT_ROOT}" || true
mkdir -p "${BOOTABLE_MOUNT_ROOT}"
# EFI
>&2 printf "[*] Format: EFI\n"
bootable::toolchain mkfs -t vfat -F 32 -n "EFI" "${BOOTABLE_DISK_LOOPBACK_DEVICE}p2"
# Swap
>&2 printf "[*] Format: Swap\n"
bootable::toolchain mkswap "${BOOTABLE_DISK_LOOPBACK_DEVICE}p3"
# Root
# Features disabled:
# - metadata_csum_seed for GRUB2 on CentOS 7 https://www.linuxquestions.org/questions/slackware-14/grub-install-error-unknown-filesystem-4175723528/
# - orphan_file for e2fsck on Fedora 38
>&2 printf "[*] Format: Root\n"
bootable::toolchain mkfs -t ext4 -O '^metadata_csum_seed,^orphan_file' "${BOOTABLE_DISK_LOOPBACK_DEVICE}p4"

# Create mount tree for chrooting and initramfs builds
>&2 printf "[*] Populate: /\n"
mkdir -p "${BOOTABLE_MOUNT_ROOT}"
mount -t ext4 "${BOOTABLE_DISK_LOOPBACK_DEVICE}p4" "${BOOTABLE_MOUNT_ROOT}"
bootable::toolchain tar --same-owner -pxf "${BOOTABLE_SCOPED_TMP_DIR}/rootfs.tar" -C "${BOOTABLE_MOUNT_ROOT}"
install --owner=0 --group=0 --mode=644 --preserve-timestamps --target-directory="${BOOTABLE_MOUNT_ROOT}/etc" "${BOOTABLE_SCOPED_TMP_DIR}/bootable-release"
>&2 printf "[*] Populate: /boot/efi\n"
mkdir -p "${BOOTABLE_MOUNT_ROOT}/boot/efi"
mount -t vfat "${BOOTABLE_DISK_LOOPBACK_DEVICE}p2" "${BOOTABLE_MOUNT_ROOT}/boot/efi"
mount_tmpfs() {
    >&2 printf "[*] Populate: %s\n" "$1"
    mkdir -p -- "${BOOTABLE_MOUNT_ROOT}$1"
    mount -t tmpfs tmpfs "${BOOTABLE_MOUNT_ROOT}$1"
}
mount_bind() {
    >&2 printf "[*] Populate: %s\n" "$1"
    if [ ! -e "${BOOTABLE_MOUNT_ROOT}$1" ]; then
        if [ -d "$1" ]; then
            mkdir -p -- "${BOOTABLE_MOUNT_ROOT}$1"
        else
            touch -- "${BOOTABLE_MOUNT_ROOT}$1"
        fi
    fi
    mount --bind "$1" "${BOOTABLE_MOUNT_ROOT}$1"
    mount --make-rslave "${BOOTABLE_MOUNT_ROOT}$1"
}
mount_bind /dev
mount_bind /proc
mount_tmpfs /run
mount_bind /run/udev # https://wiki.gentoo.org/wiki/GRUB#os-prober_and_UEFI_in_chroot
mount_bind /sys
mount_tmpfs /tmp
mount_bind /etc/resolv.conf

# Post-install hooks
# TODO: locale-gen
# TODO: Network manager
# fstab
bootable::util::invoke_hook "plugin::fstab::generate"
# initrd
bootable::util::invoke_hook "plugin::initrd::generate"
# Bootloader
bootable::util::invoke_hook "plugin::bootloader::install"
# TODO: SELinux permissions

# Cleanup
umount --recursive --verbose "${BOOTABLE_MOUNT_ROOT}"
bootable::toolchain losetup -d "${BOOTABLE_DISK_LOOPBACK_DEVICE}"

>&2 printf "[i] Image build succeeded.\n"
