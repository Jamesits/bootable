#!/hint/bash
# shellcheck disable=SC1090,SC1091 # do not warn for external scripts
# shellcheck disable=SC2034 # do not check for unused variables

BOOTABLE_DISTROS_DIR="${BOOTABLE_PROJECT_ROOT}/distros"
BOOTABLE_TOOLCHAIN_DIR="${BOOTABLE_PROJECT_ROOT}/toolchain"

if [ "$BOOTABLE_BUILD_NOCACHE" == "1" ]; then
    BOOTABLE_DOCKER_BUILD_ARGS+=("--no-cache" "--pull")
fi

# Pull in default plugins
. "${BOOTABLE_PLUGINS_DIR}/plugin-ui-require-root.sh"
. "${BOOTABLE_PLUGINS_DIR}/plugin-runtime-docker.sh"
. "${BOOTABLE_PLUGINS_DIR}/plugin-disk-gpt.sh"
. "${BOOTABLE_PLUGINS_DIR}/plugin-fstab.sh"

toolchain() {
    bootable::container::exec "${BOOTABLE_DOCKER_TOOLCHAIN_TAG}" "${BOOTABLE_PROJECT_ROOT}" "$@"
}
