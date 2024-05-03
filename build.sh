#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091 # do not warn for external scripts
set -Eeuo pipefail

# The directory where this script resides
# This variable must be set before config.sh
DLIB_PROJECT_ROOT="$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)"
DLIB_PLUGINS_DIR="${DLIB_PROJECT_ROOT}/scripts"
DLIB_DISTROS_DIR="${DLIB_PROJECT_ROOT}/distros"

# Pull in global config variables
. "${DLIB_PLUGINS_DIR}/config.sh"

if [ "$DLIB_BUILD_NOCACHE" == "1" ]; then
    DLIB_DOCKER_BUILD_ARGS+=("--no-cache" "--pull")
fi

# Pull in default plugins
. "${DLIB_PLUGINS_DIR}/plugin-ui-require-root.sh"
. "${DLIB_PLUGINS_DIR}/plugin-runtime-docker.sh"
. "${DLIB_PLUGINS_DIR}/plugin-fstab.sh"

DLIB_DISTRO="${DLIB_DISTRO:-$1}"
>&2 printf "[i] Using distro %s\n" "${DLIB_DISTRO}"
DLIB_SCOPED_TMP_DIR="${DLIB_GLOBAL_TMP_DIR}/${DLIB_DISTRO}"

mkdir -p "${DLIB_SCOPED_TMP_DIR}"
. "${DLIB_DISTROS_DIR}/${DLIB_DISTRO}/config.sh"

# Build the toolchain
DLIB_TOOLCHAIN_DIR="${DLIB_PROJECT_ROOT}/toolchain"
>&2 printf "[*] Build: toolchain...\n"
dlib::container::build::image "${DLIB_PROJECT_ROOT}" "${DLIB_TOOLCHAIN_DIR}/Containerfile" "${DLIB_DOCKER_TOOLCHAIN_TAG}"
toolchain() {
    dlib::container::exec "${DLIB_DOCKER_TOOLCHAIN_TAG}" "${DLIB_PROJECT_ROOT}" "$@"
}

# Create version info
cat > "${DLIB_SCOPED_TMP_DIR}/dlib-release" <<EOF
GIT_COMMIT=$(git rev-parse HEAD)
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_STATUS=$(git diff --quiet && echo "clean" || echo "dirty")
BUILD_TIME=$(toolchain date -u +%Y-%m-%dT%H:%M:%SZ)
BUILD_TIMESTAMP=$(toolchain date -u +%s)
BUILD_HOSTNAME=$(toolchain uname -n)
EOF

# Build the OS image
>&2 printf "[*] Build: OS image %s...\n" "${DLIB_DISTRO}"
dlib::container::build::tar "${DLIB_PROJECT_ROOT}" "${DLIB_DISTROS_DIR}/${DLIB_DISTRO}/Containerfile" "${DLIB_SCOPED_TMP_DIR}/rootfs.tar"

# Create and partition the disk (offline)
>&2 printf "[*] Creating the boot disk...\n"
toolchain fallocate -l "${DLIB_DISK_SIZE}" "${DLIB_SCOPED_TMP_DIR}/boot.img"
# Note: roughly follows the discoverable partitions specification
toolchain sgdisk --zap-all --set-alignment=2048 --align-end --move-second-header --disk-guid=00000000-0000-0000-000000000000 \
    -n "1:0:+2M"                          -c 1:grub  -t 1:21686148-6449-6E6F-744E-656564454649 \
    -n "2:0:+${DLIB_EFI_PARTITION_SIZE}"  -c 2:EFI   -t 2:C12A7328-F81F-11D2-BA4B-00A0C93EC93B \
    -n "3:0:+${DLIB_SWAP_PARTITION_SIZE}" -c 3:SWAP  -t 3:0657fd6d-a4ab-43c4-84e5-0933c84b4f4f \
    -n "4:0:0"                            -c 4:Linux -t 4:4f68bce3-e8cd-4db1-96e7-fbcaf984b709 \
    "${DLIB_SCOPED_TMP_DIR}/boot.img"
toolchain sgdisk --info "${DLIB_SCOPED_TMP_DIR}/boot.img"

# Online the disk
>&2 printf "[*] Attaching the boot disk...\n"
DLIB_DISK_LOOPBACK_DEVICE="$(toolchain losetup --find --show "${DLIB_SCOPED_TMP_DIR}/boot.img")"
toolchain partprobe "${DLIB_DISK_LOOPBACK_DEVICE}" \
    || toolchain kpartx -u "${DLIB_DISK_LOOPBACK_DEVICE}" \
    || >&2 printf "[-] Unable to refresh partition layout!\n"
if command -v udevadm >/dev/null; then
    >&2 printf "[+] Waiting for hotplug events...\n"
    udevadm settle --timeout=10
else
    >&2 printf "[-] Udev not found\n"
    sleep 10
fi

# Format all partitions
DLIB_MOUNT_ROOT="${DLIB_SCOPED_TMP_DIR}/new_root"
umount --recursive --verbose "${DLIB_MOUNT_ROOT}" || true
mkdir -p "${DLIB_MOUNT_ROOT}"
# EFI
>&2 printf "[*] Format: EFI\n"
toolchain mkfs -t vfat -F 32 -n "EFI" "${DLIB_DISK_LOOPBACK_DEVICE}p2"
# Swap
>&2 printf "[*] Format: Swap\n"
toolchain mkswap "${DLIB_DISK_LOOPBACK_DEVICE}p3"
# Root
>&2 printf "[*] Format: Root\n"
toolchain mkfs -t ext4 "${DLIB_DISK_LOOPBACK_DEVICE}p4"

# Create mount tree for chrooting and initramfs builds
>&2 printf "[*] Populate: /\n"
mkdir -p "${DLIB_MOUNT_ROOT}"
mount -t ext4 "${DLIB_DISK_LOOPBACK_DEVICE}p4" "${DLIB_MOUNT_ROOT}"
toolchain tar --same-owner -pxf "${DLIB_SCOPED_TMP_DIR}/rootfs.tar" -C "${DLIB_MOUNT_ROOT}"
install --owner=0 --group=0 --mode=644 --preserve-timestamps --target-directory="${DLIB_MOUNT_ROOT}/etc" "${DLIB_SCOPED_TMP_DIR}/dlib-release"
>&2 printf "[*] Populate: /boot/efi\n"
mkdir -p "${DLIB_MOUNT_ROOT}/boot/efi"
mount -t vfat "${DLIB_DISK_LOOPBACK_DEVICE}p2" "${DLIB_MOUNT_ROOT}/boot/efi"
>&2 printf "[*] Populate: /dev\n"
mount --bind /dev "${DLIB_MOUNT_ROOT}/dev"
>&2 printf "[*] Populate: /proc\n"
mount --bind /proc "${DLIB_MOUNT_ROOT}/proc"
>&2 printf "[*] Populate: /sys\n"
mount --bind /sys "${DLIB_MOUNT_ROOT}/sys"
>&2 printf "[*] Populate: /tmp\n"
mount -t tmpfs tmpfs "${DLIB_MOUNT_ROOT}/tmp"

# Post-install hooks
hook() {
    >&2 printf "[*] Hook: %s\n" "$1"
    "dlib::$1"
}
# TODO: Network manager
# fstab
hook "plugin::fstab::generate"
# initrd
hook "plugin::initrd::generate"
# Bootloader
hook "plugin::bootloader::install"
# TODO: SELinux permissions

# Cleanup
umount --recursive --verbose "${DLIB_MOUNT_ROOT}"
toolchain losetup -d "${DLIB_DISK_LOOPBACK_DEVICE}"

>&2 printf "[i] Image build succeeded.\n"
