#!/hint/bash

# Caveats
# GRUB2 install prefix
DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_PREFIX=${DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_PREFIX:-/usr/sbin}
# GRUB2 identity ("grub" or "grub2")
DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_ID=${DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_ID:-grub}
# Debian bullseye's `grub-install` does not want to play with loop device in neither EFI nor legacy boot mode. Have to use a new `grub-install` binary.
DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_EXTERNAL_TOOLS=${DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_EXTERNAL_TOOLS:-0}
# EFI boot entry id ("BOOT" for removable installs, otherwise "GRUB")
DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_EFI_ID=${DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_EFI_ID:-BOOT}
# Enable serial console
DLIB_CAVEAT_SERIAL_CONSOLE=${DLIB_CAVEAT_SERIAL_CONSOLE:-0}

dlib::plugin::bootloader::install() {
    # detect grub
    local GRUB_INSTALL=("${DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_PREFIX}/${DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_ID}-install")
    local GRUB_MKCONFIG=("${DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_PREFIX}/${DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_ID}-mkconfig")

    # EFI
    >&2 printf "[*] GRUB: EFI\n"
    # Notes:
    # - TODO: Temporary using `--removable` to generate bootx64.efi; should use shim instead for secure boot compatibility
    # - TODO: use --uefi-secure-boot
    # - DO NOT specify `--compress=xz` or `--core-compress=xz` for EFI installation; it breaks legacy boot, and I don't know why
    if [ "${DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_EXTERNAL_TOOLS}" == '0' ]; then
        chroot "${DLIB_MOUNT_ROOT}" "${GRUB_INSTALL[@]}" --target=x86_64-efi --recheck --force --skip-fs-probe --efi-directory=/boot/efi --no-nvram --removable "${DLIB_DISK_LOOPBACK_DEVICE}"
    else
        toolchain /usr/sbin/grub-install --target=x86_64-efi --recheck --force --skip-fs-probe --no-nvram --removable \
            --efi-directory="${DLIB_MOUNT_ROOT}/boot/efi" \
            --directory="${DLIB_MOUNT_ROOT}/usr/lib/grub/x86_64-efi" \
            --locale-directory="${DLIB_MOUNT_ROOT}/usr/share/locale" \
            --boot-directory="${DLIB_MOUNT_ROOT}/boot" \
            "${DLIB_DISK_LOOPBACK_DEVICE}"
    fi

    # Legacy
    >&2 printf "[*] GRUB: legacy\n"
    # Notes:
    # - QEMU/SeaBIOS requires either `--compress=xz --core-compress=xz` or `--disk-module=native` to boot; otherwise GRUB2 resets itself on any disk read (e.g. during the `search` command) https://www.reddit.com/r/coreboot/comments/9353qf/
    # - `--compress=xz` leads to `/usr/sbin/grub-install: warning: can't compress `/usr/lib/grub/i386-pc/acpi.mod' to `/boot/grub/i386-pc/acpi.mod'.` on some versions
    # - `--core-compress=` is not recognized on some GRUB2 versions due to a bug https://savannah.gnu.org/bugs/?60067 https://lists.gnu.org/archive/html/grub-devel/2018-09/msg00018.html;
    if [ "${DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_EXTERNAL_TOOLS}" == '0' ]; then
        chroot "${DLIB_MOUNT_ROOT}" "${GRUB_INSTALL[@]}" --target=i386-pc --recheck --force --skip-fs-probe --disk-module=native "${DLIB_DISK_LOOPBACK_DEVICE}"
    else
        toolchain /usr/sbin/grub-install --target=i386-pc --recheck --force --skip-fs-probe --disk-module=native \
            --directory="${DLIB_MOUNT_ROOT}/usr/lib/grub/i386-pc" \
            --locale-directory="${DLIB_MOUNT_ROOT}/usr/share/locale" \
            --boot-directory="${DLIB_MOUNT_ROOT}/boot" \
            "${DLIB_DISK_LOOPBACK_DEVICE}"
    fi

    # Update GRUB config
    _grub2_config_set() {
        local GRUB_CONFIG="$1"
        local KEY="$2"
        local VALUE="$3"

        if grep "${KEY}=" "${GRUB_CONFIG}" >/dev/null; then
            sed -Ei'' "s/^#?${KEY}=.*$/${KEY}=\"${VALUE}\"/g" "${GRUB_CONFIG}"
        else
            printf '%s="%s"\n' "${KEY}" "${VALUE}" >> "${GRUB_CONFIG}"
        fi
    }

    _grub2_config_unset() {
        local GRUB_CONFIG="$1"
        local KEY="$2"

        sed -Ei'' "s/^${KEY}=(.*)$/#${KEY}=\1/g" "${GRUB_CONFIG}"
    }

    >&2 printf "[*] GRUB: config\n"
    local GRUB_CONFIG="${DLIB_MOUNT_ROOT}/etc/default/grub"
    # Disable os-prober
    _grub2_config_set "${GRUB_CONFIG}" "GRUB_DISABLE_OS_PROBER" "true"
    # Enable serial console
    if [ "${DLIB_CAVEAT_SERIAL_CONSOLE}" == "1" ]; then
        _grub2_config_set "${GRUB_CONFIG}" "GRUB_TERMINAL_INPUT" "console serial"
        _grub2_config_set "${GRUB_CONFIG}" "GRUB_TERMINAL_OUTPUT" "gfxterm serial"
        # Unset GRUB_TERMINAL: on EFI environments, GRUB_TERMINAL="console serial" leads to double outputs
        _grub2_config_unset "${GRUB_CONFIG}" "GRUB_TERMINAL"
        # Get rid of the serial parameters warning
        _grub2_config_set "${GRUB_CONFIG}" "GRUB_SERIAL_COMMAND" "serial"
    fi
    # Unfuck serial GRUB menu for Ubuntu
    # https://girondi.net/post/ubuntu_console/
    # https://web.archive.org/web/20221207112654/https://blog.wataash.com/ubuntu_console/
    _grub2_config_set "${GRUB_CONFIG}" "GRUB_HIDDEN_TIMEOUT_QUIET" "false"
    _grub2_config_set "${GRUB_CONFIG}" "GRUB_TIMEOUT_STYLE" "menu"
    _grub2_config_set "${GRUB_CONFIG}" "GRUB_TIMEOUT" "3"

    # Kernel commandline for normal + recovery
    # Notes:
    # - `edd=off` required for Fedora kernels; otherwise resets very early during boot
    if [ "${DLIB_CAVEAT_SERIAL_CONSOLE}" == "1" ]; then
        _grub2_config_set "${GRUB_CONFIG}" "GRUB_CMDLINE_LINUX" "mitigations=off tsx_async_abort=off console=ttyS0 console=tty0 edd=off"
    fi

    # generate full GRUB2 config
    _grub2_generate_config() {
        if [ -d "$(dirname "${DLIB_MOUNT_ROOT}$1")" ]; then
            >&2 printf "[+] GRUB: regenerate config on %s\n" "$1"
            PATH=/usr/sbin:/sbin:/usr/bin:/bin:$PATH chroot "${DLIB_MOUNT_ROOT}" "${GRUB_MKCONFIG[@]}" -o "$1"
        else
            >&2 printf "[-] GRUB: skipped regenerate config on %s\n" "$1"
        fi
    }

    # generate chain load config
    # This file will normally be generated during `grub-install` and does not need to be updated
    # https://ubuntuforums.org/showthread.php?t=2485384
    _grub2_genreate_bootstrap_config() {
        cat > "${DLIB_MOUNT_ROOT}$1" <<EOF
search.fs_uuid $(toolchain blkid -s UUID -o value "${DLIB_DISK_LOOPBACK_DEVICE}p4") root
set prefix=(\$root)'/boot/${DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_ID}'
configfile \$prefix/grub.cfg
EOF
    }

    # for legacy boot
    _grub2_generate_config "/boot/${DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_ID}/grub.cfg"

    # for EFI
    # Caveats for Canonical signed GRUB2 loader:
    # - `/boot/efi/EFI/$id` will be a special phase 1 config
    # - the actual config will be in `/boot/efi/EFI/ubuntu/grub.cfg`
    # - GRUB installs with a non-default bootloader id will not be able to boot, unless a corresponding EFI entry is created
    # https://askubuntu.com/a/1406590
    mkdir -p -- "${DLIB_MOUNT_ROOT}/boot/efi/EFI/${DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_EFI_ID}"
    _grub2_genreate_bootstrap_config "/boot/efi/EFI/${DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_EFI_ID}/grub.cfg"
    # Ubuntu noble: `prefix` is set to `(hd0,gpt2)/boot/grub' for an unknown reason, causing GRUB2 to enter recovery shell automatically, but `normal` works in the shell.
    # This can be debugged by using `set` in the recovery shell. Here's a workaround.
    # This file is harmless for other distros.
    mkdir -p -- "${DLIB_MOUNT_ROOT}/boot/efi/boot/${DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_ID}"
    _grub2_genreate_bootstrap_config "/boot/efi/boot/${DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_ID}/grub.cfg"
}
