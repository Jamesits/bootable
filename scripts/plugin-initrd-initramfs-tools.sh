#!/hint/bash

bootable::plugin::initrd::generate() {
    >&2 printf "[*] initramfs-tools...\n"
    # FIXME: should skip autodetect
    bootable::util:chroot "${BOOTABLE_MOUNT_ROOT}" /bin/bash -c "set -Eeuo pipefail; export PATH=/usr/sbin:/sbin:/usr/bin:/bin:\$PATH; update-initramfs -u -k all"
}
