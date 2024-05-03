#!/hint/bash

dlib::plugin::initrd::generate() {
    >&2 printf "[*] initramfs-tools...\n"
    # FIXME: should skip autodetect
    chroot "${DLIB_MOUNT_ROOT}" /bin/bash -c "export PATH=/sbin:/usr/sbin:$PATH; update-initramfs -u -k all"
}
