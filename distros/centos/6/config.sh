#!/hint/bash
# shellcheck disable=SC1090,SC1091 # do not warn for external scripts
# shellcheck disable=SC2034 # do not check for unused variables

# load plugins
. "${DLIB_PLUGINS_DIR}/plugin-disk-mbr.sh"
DLIB_PLUGIN_INITRD_DRACUT_CAVEAT_REGENERATE_ALL=0
. "${DLIB_PLUGINS_DIR}/plugin-initrd-dracut.sh"
. "${DLIB_PLUGINS_DIR}/plugin-bootloader-grub0.sh"

export DLIB_SOURCE_IMAGE="registry.hub.docker.com/library/centos:6"
