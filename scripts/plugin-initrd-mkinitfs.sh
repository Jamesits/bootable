#!/hint/bash
# FIXME: does not boot for now

bootable::plugin::initrd::generate() {
    >&2 printf "[*] mkinitfs...\n"
    for kp in "${BOOTABLE_MOUNT_ROOT}/lib/modules/"*; do
        local KERNEL
        KERNEL="$(basename "$kp")"
        chroot "${BOOTABLE_MOUNT_ROOT}" /bin/ash -c "set -Eeu; export PATH=/usr/sbin:/sbin:/usr/bin:/bin:\$PATH; for i in /lib/modules/*; do mkinitfs $KERNEL; done"
    done
}
