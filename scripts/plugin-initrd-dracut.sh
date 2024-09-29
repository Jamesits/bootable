#!/hint/bash

BOOTABLE_PLUGIN_INITRD_DRACUT_CAVEAT_REGENERATE_ALL=${BOOTABLE_PLUGIN_INITRD_DRACUT_CAVEAT_REGENERATE_ALL:-1}

bootable::plugin::initrd::generate() {
    >&2 printf "[*] dracut...\n"
    local DRACUT_ARGS=(--no-hostonly --no-hostonly-cmdline --no-hostonly-i18n --persistent-policy=by-uuid --fstab)

    if [ "${BOOTABLE_PLUGIN_INITRD_DRACUT_CAVEAT_REGENERATE_ALL}" == "1" ]; then
        bootable::util:chroot "${BOOTABLE_MOUNT_ROOT}" dracut --regenerate-all --force "${DRACUT_ARGS[@]}"
    else
        # - Old dracut versions does not support `--regenerate-all` https://rephlex.de/blog/2017/05/30/quick-tip-how-to-rebuild-all-initrds-with-dracut-in-centos-67/
        bootable::util:chroot "${BOOTABLE_MOUNT_ROOT}" /bin/bash -c "set -Eeuo pipefail; (rpm -qa | grep kernel | grep -v headers | grep -v tools | sed 's/^kernel\-//g' | xargs -i dracut -v ${DRACUT_ARGS[*]} -f /boot/initramfs-{}.img {})"
    fi
}
