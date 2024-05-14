#!/hint/bash

DLIB_PLUGIN_INITRD_DRACUT_CAVEAT_REGENERATE_ALL=${DLIB_PLUGIN_INITRD_DRACUT_CAVEAT_REGENERATE_ALL:-1}

dlib::plugin::initrd::generate() {
    >&2 printf "[*] dracut...\n"

    if [ "${DLIB_PLUGIN_INITRD_DRACUT_CAVEAT_REGENERATE_ALL}" == "1" ]; then
        chroot "${DLIB_MOUNT_ROOT}" /bin/bash -c "set -Eeuo pipefail; export PATH=/usr/sbin:/sbin:/usr/bin:/bin:$PATH; dracut --regenerate-all --force"
    else
        # - Old dracut versions does not support `--regenerate-all` https://rephlex.de/blog/2017/05/30/quick-tip-how-to-rebuild-all-initrds-with-dracut-in-centos-67/
        chroot "${DLIB_MOUNT_ROOT}" /bin/bash -c "set -Eeuo pipefail; export PATH=/usr/sbin:/sbin:/usr/bin:/bin:$PATH; (rpm -qa | grep kernel | grep -v headers | grep -v tools | sed 's/^kernel\-//g' | xargs -i dracut -v -f /boot/initramfs-{}.img {})"
    fi
}
