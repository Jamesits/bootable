#!/hint/bash
# shellcheck disable=SC1090,SC1091 # do not warn for external scripts
# shellcheck disable=SC2034 # do not check for unused variables

# load plugins
. "${DLIB_PLUGINS_DIR}/plugin-initrd-initramfs-tools.sh"
DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_EXTERNAL_TOOLS=1
. "${DLIB_PLUGINS_DIR}/plugin-bootloader-grub2.sh"

export DLIB_SOURCE_IMAGE="registry.hub.docker.com/library/debian:bullseye-slim"
