#!/hint/bash
# shellcheck disable=SC1090,SC1091 # do not warn for external scripts
# shellcheck disable=SC2034 # do not check for unused variables

# load plugins
. "${BOOTABLE_PLUGINS_DIR}/plugin-initrd-dracut.sh"
BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_ID="grub2"
BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_EFI_ID="almalinux"
BOOTABLE_PLUGIN_BOOTLOADER_GRUB2_CAVEAT_DNF_SB=1
. "${BOOTABLE_PLUGINS_DIR}/plugin-bootloader-grub2.sh"

export BOOTABLE_SOURCE_IMAGE="registry.hub.docker.com/library/almalinux:8"
