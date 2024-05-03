#!/hint/bash
# shellcheck disable=SC1090,SC1091 # do not warn for external scripts
# shellcheck disable=SC2034 # do not check for unused variables

# load plugins
. "${DLIB_PLUGIN_DIR}/plugin-initrd-mkinitcpio.sh"
. "${DLIB_PLUGIN_DIR}/plugin-bootloader-grub.sh"
