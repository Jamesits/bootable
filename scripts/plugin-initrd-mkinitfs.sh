#!/hint/bash
# FIXME: does not boot for now

dlib::plugin::initrd::generate() {
    >&2 printf "[*] mkinitfs...\n"
    for kp in "${DLIB_MOUNT_ROOT}/lib/modules/"*; do
        local KERNEL
        KERNEL="$(basename "$kp")"
        chroot "${DLIB_MOUNT_ROOT}" /bin/ash -c "set -Eeu; export PATH=/usr/sbin:/sbin:/usr/bin:/bin:$PATH; for i in /lib/modules/*; do mkinitfs $KERNEL; done"
    done
}
