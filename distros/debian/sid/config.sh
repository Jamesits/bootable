#!/hint/bash
# shellcheck disable=SC1090,SC1091 # do not warn for external scripts
# shellcheck disable=SC2034 # do not check for unused variables

# load plugins
. "${BOOTABLE_PLUGINS_DIR}/plugin-initrd-initramfs-tools.sh"
. "${BOOTABLE_PLUGINS_DIR}/plugin-bootloader-grub2.sh"

export BOOTABLE_SOURCE_IMAGE="registry.hub.docker.com/library/debian:sid-slim"
