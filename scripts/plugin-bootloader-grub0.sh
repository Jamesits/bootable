#!/hint/bash

bootable::plugin::bootloader::install() {
    # Legacy
    >&2 printf "[*] GRUB0: legacy\n"
    # https://bbs.archlinux.org/viewtopic.php?pid=936051#p936051

    cat > "${BOOTABLE_MOUNT_ROOT}/boot/grub/device.map" <<EOF
(hd0) ${BOOTABLE_DISK_LOOPBACK_DEVICE}
EOF
    PATH=/usr/sbin:/sbin:/usr/bin:/bin chroot "${BOOTABLE_MOUNT_ROOT}" "grub-install" --root-directory=/ --no-floppy "${BOOTABLE_DISK_LOOPBACK_DEVICE}"
}
