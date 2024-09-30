#!/hint/bash
# shellcheck disable=SC1090,SC1091 # do not warn for external scripts
# shellcheck disable=SC2034 # do not check for unused variables

BOOTABLE_DISTROS_DIR="${BOOTABLE_PROJECT_ROOT}/distros"
BOOTABLE_TOOLCHAIN_DIR="${BOOTABLE_PROJECT_ROOT}/toolchain"

if [ "$BOOTABLE_BUILD_NOCACHE" == "1" ]; then
    BOOTABLE_DOCKER_BUILD_ARGS+=("--no-cache" "--pull")
fi

# Pull in default plugins
. "${BOOTABLE_PLUGINS_DIR}/plugin-runtime-docker.sh"
. "${BOOTABLE_PLUGINS_DIR}/plugin-fstab.sh"

bootable::toolchain() {
    bootable::container::exec "${BOOTABLE_DOCKER_TOOLCHAIN_TAG}" "${BOOTABLE_PROJECT_ROOT}" "$@"
}

bootable::util::release_file() {
    cat <<EOF
GIT_COMMIT=$(git rev-parse HEAD)
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_STATUS=$(git diff --quiet && echo "clean" || echo "dirty")
BUILD_TIME=$(bootable::toolchain date -u +%Y-%m-%dT%H:%M:%SZ)
BUILD_TIMESTAMP=$(bootable::toolchain date -u +%s)
BUILD_HOSTNAME=$(bootable::toolchain uname -n)
EOF
}

bootable::util::source() {
    if [ -f "$1" ]; then
        . "$1"
    fi
}

# Usage: bootable::util::load_plugin <config-dir> <plugin-name>
bootable::util::load_plugin() {
    if [ -f "$1/plugin-$2.sh" ]; then
        >&2 printf "[*] Loading user plugin: %s\n" "$2"
        . "$1/plugin-$2.sh"
    else
        . "${BOOTABLE_PLUGINS_DIR}/plugin-$2.sh"
    fi
}

# Usage: bootable::util::invoke_hook <config-dir> <hook-name>
bootable::util::invoke_hook() {
    >&2 printf "[*] Hook: %s\n" "$1"
    "bootable::$1"
}

# Usage: bootable::util::random_string <length>
bootable::util::random_string() {
    tr -dc A-Za-z0-9 </dev/urandom | head -c "$1"; echo
}

# Remove all files under the directory recursively, but not the directory itself.
# Usage: bootable::util::clean_dir <dir>
bootable::util::clean_dir() {
    find "$1" -mindepth 1 -delete
}

# Clean up the root filesystem
# Usage: bootable::util::sysprep <root-dir>
bootable::util::sysprep() {
    local ROOTDIR="$1"
    >&2 printf "[*] Sysprep: %s\n" "${ROOTDIR}"

    # TODO: adopt https://github.com/libguestfs/guestfs-tools/tree/master/sysprep

    # clean up temporary files
    bootable::util::clean_dir "${ROOTDIR}/run"
    bootable::util::clean_dir "${ROOTDIR}/tmp"
    # remove container markers introduced by the build system
    # https://github.com/systemd/systemd/blob/9afb4aea0070fe9a9b3fe0f452fab17e1205219c/src/basic/virt.c#L658
    rm -fv --one-file-system "${ROOTDIR}/.dockerenv" "${ROOTDIR}/.containerenv"
    # remove machine ID
    rm -fv --one-file-system "${ROOTDIR}/etc/machine-id" "${ROOTDIR}/var/lib/dbus/machine-id"
}

# Bind mount file or directory $1 to $2
bootable::util::mount_bind() {
    if [ ! -e "$2" ]; then
        if [ -d "$1" ]; then
            mkdir -p -- "$2"
        else
            touch -- "$2"
        fi
    fi
    mount --rbind "$1" "$2"
    mount --make-rslave "$2"
}

bootable::util::chroot_setup() {
    local ROOTDIR="$1"

    # create a mount namespace
    bootable::util::mount_bind "${ROOTDIR}" "${ROOTDIR}"

    # /proc
    mount -t proc -o nosuid,noexec,nodev proc "${ROOTDIR}/proc"
    # /sys
    bootable::util::mount_bind "/sys" "${ROOTDIR}/sys"
    # /dev
    # full /dev is required for GRUB2 installation
    bootable::util::mount_bind "/dev" "${ROOTDIR}/dev"
    # mount -t tmpfs tmpfs "${ROOTDIR}/dev"
    # ln -sf "/proc/self/fd" "${ROOTDIR}/dev/fd"
    # ln -sf "/proc/self/fd/0" "${ROOTDIR}/dev/stdin"
    # ln -sf "/proc/self/fd/1" "${ROOTDIR}/dev/stdout"
    # ln -sf "/proc/self/fd/2" "${ROOTDIR}/dev/stderr"
    # bootable::util::mount_bind "/dev/full" "${ROOTDIR}/dev/full"
    # bootable::util::mount_bind "/dev/null" "${ROOTDIR}/dev/null"
    # bootable::util::mount_bind "/dev/random" "${ROOTDIR}/dev/random"
    # bootable::util::mount_bind "/dev/urandom" "${ROOTDIR}/dev/urandom"
    # bootable::util::mount_bind "/dev/tty" "${ROOTDIR}/dev/tty"
    # bootable::util::mount_bind "/dev/zero" "${ROOTDIR}/dev/zero"
    # /run
    mount -t tmpfs -o nosuid,nodev,mode=0755 tmpfs "${ROOTDIR}/run"
    # /run/udev
    # https://wiki.gentoo.org/wiki/GRUB#os-prober_and_UEFI_in_chroot
    bootable::util::mount_bind "/run/udev" "${ROOTDIR}/run/udev"
    # /tmp
    mount -t tmpfs -o mode=1777,strictatime,nodev,nosuid tmpfs "${ROOTDIR}/tmp"
    # /etc/resolv.conf
    bootable::util::mount_bind "/etc/resolv.conf" "${ROOTDIR}/etc/resolv.conf"
}

bootable::util::chroot_teardown() {
    for dir in "$1/"*; do
        umount --recursive --verbose --lazy "${dir}" || true
    done
}

bootable::util:chroot() {
    local ROOTDIR="$1"
    shift
    >&2 printf "[i] chroot: %s %s\n" "${ROOTDIR}" "$*"
    # Debian Bullseye: need /sbin and /bin added to the PATH since it is not usrmerge'd yet
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" unshare --fork --mount --root "${ROOTDIR}" "$@"
}
