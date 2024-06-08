#!/hint/bash

bootable::plugin::initrd::generate() {
    >&2 printf "[*] mkinitcpio...\n"
    # FIXME: specifying --skiphooks with --allpresets seems to be not working, should use dropins instead.
    # Booting with QEMU works nonetheless. Would fix it later.
    chroot "${BOOTABLE_MOUNT_ROOT}" mkinitcpio --skiphooks autodetect --allpresets
}
