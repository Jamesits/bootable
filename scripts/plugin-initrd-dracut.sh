#!/hint/bash

dlib::plugin::initrd::generate() {
    >&2 printf "[*] dracut...\n"
    chroot "${DLIB_MOUNT_ROOT}" dracut --regenerate-all -f
}
