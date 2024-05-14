#!/hint/bash
# shellcheck disable=SC1090,SC1091 # do not warn for external scripts
# shellcheck disable=SC2034 # do not check for unused variables

# load plugins
. "${DLIB_PLUGINS_DIR}/plugin-initrd-dracut.sh"
DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_ID="grub2"
DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_EFI_ID="almalinux"
DLIB_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_DNF_SB=1
. "${DLIB_PLUGINS_DIR}/plugin-bootloader-grub2.sh"

export DLIB_SOURCE_IMAGE="registry.hub.docker.com/library/almalinux:9"
