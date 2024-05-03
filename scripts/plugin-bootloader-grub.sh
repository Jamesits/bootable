#!/hint/bash

plugin::bootloader::install() {
    # EFI
    >&2 printf "[*] GRUB: EFI\n"
    # Notes:
    # - Temporary using `--removable` to generate bootx64.efi; should use shim instead for secure boot compatibility
    # - DO NOT specify `--compress=xz` or `--core-compress=xz` for EFI installation; it breaks legacy boot, and I don't know why
    chroot "${LIB_MOUNT_ROOT}" grub-install --target=x86_64-efi --recheck --force --skip-fs-probe --efi-directory=/boot/efi --no-nvram --removable

    # Legacy
    >&2 printf "[*] GRUB: legacy\n"
    chroot "${LIB_MOUNT_ROOT}" grub-install --target=i386-pc --compress=xz --core-compress=xz --recheck --force --skip-fs-probe "${LIB_DISK_LOOPBACK_DEVICE}"

    # Generate config
    >&2 printf "[*] GRUB: config\n"
    sed -Ei 's/^#?GRUB_TERMINAL_INPUT=.*$/GRUB_TERMINAL_INPUT="console serial"/g' "${LIB_MOUNT_ROOT}/etc/default/grub"
    sed -Ei 's/^#?GRUB_TERMINAL_OUTPUT=.*$/GRUB_TERMINAL_OUTPUT="gfxterm serial"/g' "${LIB_MOUNT_ROOT}/etc/default/grub"
    chroot "${LIB_MOUNT_ROOT}" grub-mkconfig -o /boot/grub/grub.cfg
}
