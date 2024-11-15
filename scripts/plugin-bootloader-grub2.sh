#!/hint/bash

# Caveats
# GRUB2 identity ("grub" or "grub2")
BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_PREFIX="$(bootable::container::label::get "${BOOTABLE_BUILD_IMAGE_TAG}" "bootable.plugin.bootloader.grub2.prefix" "grub")"
# Debian bullseye's `grub-install` does not want to play with loop device in neither EFI nor legacy boot mode. Have to use a new `grub-install` binary.
BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_EXTERNAL_TOOLS="$(bootable::container::label::get "${BOOTABLE_BUILD_IMAGE_TAG}" "bootable.plugin.bootloader.grub2.external-tools" "1")"
# Legacy boot distro name
# - "grub" by default
# - Usually set to the distro name
BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_DISTRO_LEGACY="$(bootable::container::label::get "${BOOTABLE_BUILD_IMAGE_TAG}" "bootable.plugin.bootloader.grub2.distro-legacy" "grub")"
# EFI boot entry id
# - "BOOT" for removable installs
# - "GRUB" by default
# - Usually set to the distro name
BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_DISTRO_EFI="$(bootable::container::label::get "${BOOTABLE_BUILD_IMAGE_TAG}" "bootable.plugin.bootloader.grub2.distro-efi" "BOOT")"
# Use DNF to install the signed GRUB2 and shim binary
BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_DNF_SB="$(bootable::container::label::get "${BOOTABLE_BUILD_IMAGE_TAG}" "bootable.plugin.bootloader.grub2.dnf-secure-boot" "0")"
# Enable serial console
BOOTABLE_CAVEAT_SERIAL_CONSOLE=${BOOTABLE_CAVEAT_SERIAL_CONSOLE:-0}

_grub2_unfuck_env() {
    # Unfuck grubenv
    # *EL: `/boot/grub2/grubenv`` is symlinked to `../efi/EFI/centos/grubenv` which does not exist and breaks `grub-install`
    if [ -L "${BOOTABLE_MOUNT_ROOT}/boot/${BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_DISTRO_LEGACY}/grubenv" ]; then
        >&2 printf "[!] GRUB2: fix grubenv\n"
        rm -fv "${BOOTABLE_MOUNT_ROOT}/boot/${BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_DISTRO_LEGACY}/grubenv"
        bootable::util:chroot "${BOOTABLE_MOUNT_ROOT}" grub2-editenv "/boot/${BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_DISTRO_LEGACY}/grubenv" create
    fi
}

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

# generate full GRUB2 config
_grub2_generate_config() {
    if [ -d "$(dirname "${BOOTABLE_MOUNT_ROOT}$1")" ]; then
        >&2 printf "[+] GRUB: regenerate config on %s\n" "$1"
        bootable::util:chroot "${BOOTABLE_MOUNT_ROOT}" "${GRUB_MKCONFIG[@]}" -o "$1"
    else
        >&2 printf "[-] GRUB: skipped regenerate config on %s\n" "$1"
    fi
}

# generate chain load config
# This file will normally be generated during `grub-install` and does not need to be updated
# https://ubuntuforums.org/showthread.php?t=2485384
_grub2_generate_bootstrap_config() {
    cat > "${BOOTABLE_MOUNT_ROOT}$1" <<EOF
search.fs_uuid $(bootable::toolchain blkid -s UUID -o value "${BOOTABLE_DISK_LOOPBACK_DEVICE}p4") root
set prefix=(\$root)'/boot/${BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_DISTRO_LEGACY}'
configfile \$prefix/grub.cfg
EOF
}

# Fix GRUB2 config file on CentOS 7 to be compatible on both EFI and legacy boot
_grub2_legacy_compat_fix() {
    sed -Ei'' 's/linuxefi\ /linux\ /g; s/initrdefi\ /initrd\ /g' "$1"
}

bootable::plugin::bootloader::install() {
    # detect grub
    local GRUB_INSTALL=("${BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_PREFIX}-install")
    local GRUB_MKCONFIG=("${BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_PREFIX}-mkconfig")

    _grub2_unfuck_env

    # set GRUB defaults
    local GRUB_CONFIG="${BOOTABLE_MOUNT_ROOT}/etc/default/grub"
    # Disable os-prober
    _grub2_config_set "${GRUB_CONFIG}" "GRUB_DISABLE_OS_PROBER" "true"
    # Enable serial console
    if [ "${BOOTABLE_CAVEAT_SERIAL_CONSOLE}" == "1" ]; then
        _grub2_config_set "${GRUB_CONFIG}" "GRUB_TERMINAL_INPUT" "console serial"
        if [ "${BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_DNF_SB}" == '1' ]; then
            # Output: "gfxterm serial" does not work on CentOS 8
            _grub2_config_set "${GRUB_CONFIG}" "GRUB_TERMINAL_OUTPUT" "console serial"
        else
            _grub2_config_set "${GRUB_CONFIG}" "GRUB_TERMINAL_OUTPUT" "gfxterm serial"
        fi
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
    if [ "${BOOTABLE_CAVEAT_SERIAL_CONSOLE}" == "1" ]; then
        _grub2_config_set "${GRUB_CONFIG}" "GRUB_CMDLINE_LINUX" "mitigations=off tsx_async_abort=off console=ttyS0 console=tty0 edd=off"
    fi

    # GRUB install: EFI
    >&2 printf "[*] GRUB2: EFI\n"
    # Notes:
    # - TODO: Temporary using `--removable` to generate bootx64.efi; should use shim instead for secure boot compatibility
    # - TODO: use --uefi-secure-boot
    # - DO NOT specify `--compress=xz` or `--core-compress=xz` for EFI installation; it breaks legacy boot, and I don't know why
    if [ "${BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_EXTERNAL_TOOLS}" == '1' ]; then
        # Debian bullseye: /usr/sbin/grub-install: error: cannot find a GRUB drive for /dev/loop25p2.  Check your device.map.
        bootable::toolchain /usr/sbin/grub-install --target=x86_64-efi --recheck --force --skip-fs-probe --no-nvram --removable \
            --efi-directory="${BOOTABLE_MOUNT_ROOT}/boot/efi" \
            --directory="${BOOTABLE_MOUNT_ROOT}/usr/lib/grub/x86_64-efi" \
            --locale-directory="${BOOTABLE_MOUNT_ROOT}/usr/share/locale" \
            --boot-directory="${BOOTABLE_MOUNT_ROOT}/boot" \
            "${BOOTABLE_DISK_LOOPBACK_DEVICE}"
    elif [ "${BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_DNF_SB}" == '1' ]; then
        # RPM distros: does not need to do anything, just copy /boot/efi to the EFI partition

        # *EL 8: grub2-install does not work on UEFI systems since it want you to install the signed version of the EFI bootloader while grub2-install must alter the EFI binary
        # Notes:
        # - Removable install is not supported in this way
        # - It would make /boot/grub/grubenv a symlink which breaks everything
        # https://bugzilla.redhat.com/show_bug.cgi?id=1917213
        # https://docs.fedoraproject.org/en-US/fedora/rawhide/system-administrators-guide/kernel-module-driver-configuration/Working_with_the_GRUB_2_Boot_Loader/#sec-Resetting_and_Reinstalling_GRUB_2
        # bootable::util:chroot "${BOOTABLE_MOUNT_ROOT}" dnf -y reinstall grub2-efi shim
        # bootable::util:chroot "${BOOTABLE_MOUNT_ROOT}" dnf clean all

        # # *EL 8: manually copy kernel to /boot (this should happen during the installation of "kernel" package)
        # for kp in "${BOOTABLE_MOUNT_ROOT}/lib/modules/"*; do
        #     local KERNEL
        #     KERNEL="$(basename "$kp")"
        #     cp -v "${kp}/vmlinuz" "${BOOTABLE_MOUNT_ROOT}/boot/vmlinuz-${KERNEL}"
        # done
        true
    else
        # DEB distros: grub-install required
        # use the grub-install binary that comes with the distro
        bootable::util:chroot "${BOOTABLE_MOUNT_ROOT}" "${GRUB_INSTALL[@]}" --target=x86_64-efi --recheck --force --skip-fs-probe --efi-directory=/boot/efi --no-nvram --removable "${BOOTABLE_DISK_LOOPBACK_DEVICE}"
    fi

    # GRUB install: Legacy
    >&2 printf "[*] GRUB2: legacy\n"
    # Notes:
    # - QEMU/SeaBIOS requires either `--compress=xz --core-compress=xz` or `--disk-module=native` to boot; otherwise GRUB2 resets itself on any disk read (e.g. during the `search` command) https://www.reddit.com/r/coreboot/comments/9353qf/
    # - `--compress=xz` leads to `/usr/sbin/grub-install: warning: can't compress `/usr/lib/grub/i386-pc/acpi.mod' to `/boot/grub/i386-pc/acpi.mod'.` on some versions
    # - `--core-compress=` is not recognized on some GRUB2 versions due to a bug https://savannah.gnu.org/bugs/?60067 https://lists.gnu.org/archive/html/grub-devel/2018-09/msg00018.html;
    if [ "${BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_EXTERNAL_TOOLS}" == '1' ]; then
        # Debian bullseye: /usr/sbin/grub-install: error: cannot find a GRUB drive for /dev/loop26p4.  Check your device.map.
        bootable::toolchain /usr/sbin/grub-install --target=i386-pc --recheck --force --skip-fs-probe --disk-module=native \
            --directory="${BOOTABLE_MOUNT_ROOT}/usr/lib/grub/i386-pc" \
            --locale-directory="${BOOTABLE_MOUNT_ROOT}/usr/share/locale" \
            --boot-directory="${BOOTABLE_MOUNT_ROOT}/boot" \
            "${BOOTABLE_DISK_LOOPBACK_DEVICE}"
    else
        # use the grub-install binary that comes with the distro
        bootable::util:chroot "${BOOTABLE_MOUNT_ROOT}" "${GRUB_INSTALL[@]}" --target=i386-pc --recheck --force --skip-fs-probe --disk-module=native "${BOOTABLE_DISK_LOOPBACK_DEVICE}"
    fi

    # Update GRUB config
    # Note:
    # - symlink to /etc/grub{,2,2-efi}.cfg is not trustworthy
    >&2 printf "[*] GRUB: config\n"
    # for legacy boot
    mkdir -p "${BOOTABLE_MOUNT_ROOT}/boot/${BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_DISTRO_LEGACY}"
    _grub2_generate_config "/boot/${BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_DISTRO_LEGACY}/grub.cfg"
    _grub2_legacy_compat_fix "${BOOTABLE_MOUNT_ROOT}/boot/${BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_DISTRO_LEGACY}/grub.cfg"

    # redirect EFI config to legacy config
    # Caveats for Canonical signed GRUB2 loader:
    # - `/boot/efi/EFI/$id` will be a special phase 1 config
    # - the actual config will be in `/boot/efi/EFI/ubuntu/grub.cfg`
    # - GRUB installs with a non-default bootloader id will not be able to boot, unless a corresponding EFI entry is created
    # https://askubuntu.com/a/1406590
    mkdir -p -- "${BOOTABLE_MOUNT_ROOT}/boot/efi/EFI/${BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_DISTRO_EFI}"
    _grub2_generate_bootstrap_config "/boot/efi/EFI/${BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_DISTRO_EFI}/grub.cfg"
    # Ubuntu noble: `prefix` is set to `(hd0,gpt2)/boot/grub' for an unknown reason, causing GRUB2 to enter recovery shell automatically, but `normal` works in the shell.
    # This can be debugged by using `set` in the recovery shell. Here's a workaround.
    # This file is harmless for other distros.
    # mkdir -p -- "${BOOTABLE_MOUNT_ROOT}/boot/efi/boot/${BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_PREFIX}"
    # _grub2_generate_bootstrap_config "/boot/efi/boot/${BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_PREFIX}/grub.cfg"

    _grub2_unfuck_env
}
