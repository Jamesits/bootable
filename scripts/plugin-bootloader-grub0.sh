#!/hint/bash

dlib::plugin::bootloader::install() {
    # Legacy
    >&2 printf "[*] GRUB0: legacy\n"
    # https://bbs.archlinux.org/viewtopic.php?pid=936051#p936051

    cat > "${DLIB_MOUNT_ROOT}/boot/grub/device.map" <<EOF
(hd0) ${DLIB_DISK_LOOPBACK_DEVICE}
EOF
    PATH=/usr/sbin:/sbin:/usr/bin:/bin chroot "${DLIB_MOUNT_ROOT}" "grub-install" --no-floppy "(hd0)"
}
