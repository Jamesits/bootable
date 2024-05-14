#!/hint/bash

dlib::plugin::initrd::generate() {
    >&2 printf "[*] initramfs-tools...\n"
    # FIXME: should skip autodetect
    chroot "${DLIB_MOUNT_ROOT}" /bin/bash -c "set -Eeuo pipefail; export PATH=/usr/sbin:/sbin:/usr/bin:/bin:$PATH; update-initramfs -u -k all"
}
