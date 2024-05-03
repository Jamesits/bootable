#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091 # do not warn for external scripts
set -Eeuo pipefail

# The directory where this script resides
# This variable must be set before config.sh
LIB_PROJECT_ROOT="$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)"
LIB_PLUGIN_DIR="${LIB_PROJECT_ROOT}/scripts"
LIB_FLAVOR_DIR="${LIB_PROJECT_ROOT}/flavors"

# Pull in global config variables
. "${LIB_PLUGIN_DIR}/config.sh"

if [ "$LIB_BUILD_NOCACHE" == "1" ]; then
    LIB_DOCKER_BUILD_ARGS+=("--no-cache" "--pull")
fi

# Pull in default plugins
. "${LIB_PLUGIN_DIR}/plugin-ui-require-root.sh"
. "${LIB_PLUGIN_DIR}/plugin-runtime-docker.sh"

LIB_FLAVOR="${LIB_FLAVOR:-$1}"
>&2 printf "[i] Using flavor %s\n" "${LIB_FLAVOR}"
LIB_SCOPED_TMP_DIR="${LIB_GLOBAL_TMP_DIR}/${LIB_FLAVOR}"

mkdir -p "${LIB_SCOPED_TMP_DIR}"
. "${LIB_FLAVOR_DIR}/${LIB_FLAVOR}/config.sh"

# Build the toolchain
LIB_TOOLCHAIN_DIR="${LIB_PROJECT_ROOT}/toolchain"
>&2 printf "[*] Build: toolchain...\n"
container::build::image "${LIB_PROJECT_ROOT}" "${LIB_TOOLCHAIN_DIR}/Containerfile" "${LIB_DOCKER_TOOLCHAIN_TAG}"
toolchain() {
    container::exec "${LIB_DOCKER_TOOLCHAIN_TAG}" "${LIB_PROJECT_ROOT}" "$@"
}

# Create version info
cat > "${LIB_SCOPED_TMP_DIR}/lib-release" <<EOF
GIT_COMMIT=$(git rev-parse HEAD)
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_STATUS=$(git diff --quiet && echo "clean" || echo "dirty")
BUILD_TIME=$(toolchain date -u +%Y-%m-%dT%H:%M:%SZ)
BUILD_TIMESTAMP=$(toolchain date -u +%s)
BUILD_HOSTNAME=$(toolchain uname -n)
EOF

# Build the OS image
>&2 printf "[*] Build: OS image %s...\n" "${LIB_FLAVOR}"
container::build::tar "${LIB_PROJECT_ROOT}" "${LIB_FLAVOR_DIR}/${LIB_FLAVOR}/Containerfile" "${LIB_SCOPED_TMP_DIR}/rootfs.tar"

# Create and partition the disk (offline)
>&2 printf "[*] Creating the boot disk...\n"
toolchain fallocate -l "${LIB_DISK_SIZE}" "${LIB_SCOPED_TMP_DIR}/boot.img"
toolchain sgdisk --zap-all --set-alignment=2048 --align-end --move-second-header --disk-guid=00000000-0000-0000-000000000000 \
    -n "1:0:+1M"                         -c 1:grub  -t 1:21686148-6449-6E6F-744E-656564454649 \
    -n "2:0:+${LIB_EFI_PARTITION_SIZE}"  -c 2:EFI   -t 2:C12A7328-F81F-11D2-BA4B-00A0C93EC93B \
    -n "3:0:+${LIB_SWAP_PARTITION_SIZE}" -c 3:SWAP  -t 3:0657fd6d-a4ab-43c4-84e5-0933c84b4f4f \
    -n "4:0:0"                           -c 4:Linux -t 4:4f68bce3-e8cd-4db1-96e7-fbcaf984b709 \
    "${LIB_SCOPED_TMP_DIR}/boot.img"
toolchain sgdisk --info "${LIB_SCOPED_TMP_DIR}/boot.img"

# Online the disk
>&2 printf "[*] Attaching the boot disk...\n"
LIB_DISK_LOOPBACK_DEVICE="$(toolchain losetup --find --show "${LIB_SCOPED_TMP_DIR}/boot.img")"
toolchain partprobe "${LIB_DISK_LOOPBACK_DEVICE}" \
    || toolchain kpartx -u "${LIB_DISK_LOOPBACK_DEVICE}" \
    || >&2 printf "[-] Unable to refresh partition layout!\n"
if command -v udevadm >/dev/null; then
    >&2 printf "[+] Waiting for hotplug events...\n"
    udevadm settle --timeout=10
else
    >&2 printf "[-] Udev not found\n"
    sleep 10
fi

# Format all partitions
LIB_MOUNT_ROOT="${LIB_SCOPED_TMP_DIR}/new_root"
umount --recursive --verbose "${LIB_MOUNT_ROOT}" || true
mkdir -p "${LIB_MOUNT_ROOT}"
# EFI
>&2 printf "[*] Format: EFI\n"
toolchain mkfs -t vfat -F 32 -n "EFI" "${LIB_DISK_LOOPBACK_DEVICE}p2"
# Swap
>&2 printf "[*] Format: Swap\n"
toolchain mkswap "${LIB_DISK_LOOPBACK_DEVICE}p3"
# Root
>&2 printf "[*] Format: Root\n"
toolchain mkfs -t ext4 "${LIB_DISK_LOOPBACK_DEVICE}p4"

# Create mount tree
>&2 printf "[*] Populate: /\n"
mkdir -p "${LIB_MOUNT_ROOT}"
mount -t ext4 "${LIB_DISK_LOOPBACK_DEVICE}p4" "${LIB_MOUNT_ROOT}"
toolchain tar --same-owner -pxf "${LIB_SCOPED_TMP_DIR}/rootfs.tar" -C "${LIB_MOUNT_ROOT}"
install --owner=0 --group=0 --mode=644 --preserve-timestamps --target-directory="${LIB_MOUNT_ROOT}/etc" "${LIB_SCOPED_TMP_DIR}/lib-release"
>&2 printf "[*] Populate: /boot/efi\n"
mkdir -p "${LIB_MOUNT_ROOT}/boot/efi"
mount -t vfat "${LIB_DISK_LOOPBACK_DEVICE}p2" "${LIB_MOUNT_ROOT}/boot/efi"
>&2 printf "[*] Populate: /dev\n"
mount --bind /dev "${LIB_MOUNT_ROOT}/dev"
>&2 printf "[*] Populate: /proc\n"
mount --bind /proc "${LIB_MOUNT_ROOT}/proc"
>&2 printf "[*] Populate: /sys\n"
mount --bind /sys "${LIB_MOUNT_ROOT}/sys"
>&2 printf "[*] Populate: /tmp\n"
mount -t tmpfs tmpfs "${LIB_MOUNT_ROOT}/tmp"

# Post-install hooks
# TODO: Network manager
# TODO: fstab
# TODO: initrd
>&2 printf "[*] Hook: plugin::initrd::generate\n"
plugin::initrd::generate
# TODO: bootloader
>&2 printf "[*] Hook: plugin::bootloader::install\n"
plugin::bootloader::install
# TODO: SELinux permissions

# unmount all partitions
umount --recursive --verbose "${LIB_MOUNT_ROOT}"
toolchain losetup -d "${LIB_DISK_LOOPBACK_DEVICE}"

>&2 printf "[i] Image build succeeded.\n"
