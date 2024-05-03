#!/hint/bash
# Notes:
# - Debian bullseye's `grub-install` does not want to play with loop device in neither EFI nor legacy boot mode. Have to use a new `grub-install` binary. TODO: make this caveat optional

dlib::plugin::bootloader::install() {
    # detect grub
    local GRUB_INSTALL=()
    if [ -x "${DLIB_MOUNT_ROOT}/usr/sbin/grub-install" ]; then # Debian
        GRUB_INSTALL=("/usr/sbin/grub-install")
        GRUB_MKCONFIG=("/usr/sbin/grub-mkconfig")
    else
        GRUB_INSTALL=("grub-install")
        GRUB_MKCONFIG=("grub-mkconfig")
    fi

    # EFI
    >&2 printf "[*] GRUB: EFI\n"
    # Notes:
    # - TODO: Temporary using `--removable` to generate bootx64.efi; should use shim instead for secure boot compatibility
    # - TODO: use --uefi-secure-boot
    # - DO NOT specify `--compress=xz` or `--core-compress=xz` for EFI installation; it breaks legacy boot, and I don't know why
    # chroot "${DLIB_MOUNT_ROOT}" "${GRUB_INSTALL[@]}" --target=x86_64-efi --recheck --force --skip-fs-probe --efi-directory=/boot/efi --no-nvram --removable "${DLIB_DISK_LOOPBACK_DEVICE}p4"
    toolchain /usr/sbin/grub-install --target=x86_64-efi --recheck --force --skip-fs-probe --no-nvram --removable \
        --efi-directory="${DLIB_MOUNT_ROOT}/boot/efi" \
        --directory="${DLIB_MOUNT_ROOT}/usr/lib/grub/x86_64-efi" \
        --locale-directory="${DLIB_MOUNT_ROOT}/usr/share/locale" \
        --boot-directory="${DLIB_MOUNT_ROOT}/boot" \
        "${DLIB_DISK_LOOPBACK_DEVICE}"

    # Legacy
    >&2 printf "[*] GRUB: legacy\n"
    # Notes:
    # - QEMU/SeaBIOS requires either `--compress=xz --core-compress=xz` or `--disk-module=native` to boot; otherwise GRUB2 resets itself on any disk read (e.g. during the `search` command) https://www.reddit.com/r/coreboot/comments/9353qf/
    # - `--compress=xz` leads to `/usr/sbin/grub-install: warning: can't compress `/usr/lib/grub/i386-pc/acpi.mod' to `/boot/grub/i386-pc/acpi.mod'.` on some versions
    # - `--core-compress=` is not recognized on some GRUB2 versions due to a bug https://savannah.gnu.org/bugs/?60067 https://lists.gnu.org/archive/html/grub-devel/2018-09/msg00018.html;
    # chroot "${DLIB_MOUNT_ROOT}" "${GRUB_INSTALL[@]}" --target=i386-pc --recheck --force --skip-fs-probe --disk-module=native "${DLIB_DISK_LOOPBACK_DEVICE}"
    toolchain /usr/sbin/grub-install --target=i386-pc --recheck --force --skip-fs-probe --disk-module=native \
        --directory="${DLIB_MOUNT_ROOT}/usr/lib/grub/i386-pc" \
        --locale-directory="${DLIB_MOUNT_ROOT}/usr/share/locale" \
        --boot-directory="${DLIB_MOUNT_ROOT}/boot" \
        "${DLIB_DISK_LOOPBACK_DEVICE}"

    # Generate config
    # FIXME: disable os-prober
    >&2 printf "[*] GRUB: config\n"
    # enable serial console
    grep "GRUB_TERMINAL_INPUT" "${DLIB_MOUNT_ROOT}/etc/default/grub" \
        && sed -Ei'' 's/^#?GRUB_TERMINAL_INPUT=.*$/GRUB_TERMINAL_INPUT="console serial"/g' "${DLIB_MOUNT_ROOT}/etc/default/grub" \
        || printf 'GRUB_TERMINAL_INPUT="console serial"\n' >> "${DLIB_MOUNT_ROOT}/etc/default/grub"
    grep "GRUB_TERMINAL_OUTPUT" "${DLIB_MOUNT_ROOT}/etc/default/grub" \
        && sed -Ei'' 's/^#?GRUB_TERMINAL_OUTPUT=.*$/GRUB_TERMINAL_OUTPUT="gfxterm serial"/g' "${DLIB_MOUNT_ROOT}/etc/default/grub" \
        || printf 'GRUB_TERMINAL_OUTPUT="gfxterm serial"\n' >> "${DLIB_MOUNT_ROOT}/etc/default/grub"
    # unset GRUB_TERMINAL: on EFI environments, GRUB_TERMINAL="console serial" leads to double outputs
    # shellcheck disable=SC2016 # do not check for regex
    sed -Ei 's/^GRUB_TERMINAL=(.*)$/#GRUB_TERMINAL=$1/g' "${DLIB_MOUNT_ROOT}/etc/default/grub"
    PATH=/usr/sbin:/sbin:/usr/bin:/bin:$PATH chroot "${DLIB_MOUNT_ROOT}" "${GRUB_MKCONFIG[@]}" -o /boot/grub/grub.cfg
}
