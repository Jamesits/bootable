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
