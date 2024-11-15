#!/hint/bash
# shellcheck disable=SC2034 # do not check for unused variables

# tags
BOOTABLE_TEMP_TAG_PREFIX="localhost/bootable/build:"

# Scratch directory location
# Currently this directory should be inside $BOOTABLE_PROJECT_ROOT
BOOTABLE_GLOBAL_TMP_DIR="${BOOTABLE_PROJECT_ROOT}/tmp"

# OS image disk size
BOOTABLE_DISK_SIZE="${BOOTABLE_DISK_SIZE:-4G}"
BOOTABLE_EFI_PARTITION_SIZE="${BOOTABLE_EFI_PARTITION_SIZE:-256M}"
BOOTABLE_SWAP_PARTITION_SIZE="${BOOTABLE_SWAP_PARTITION_SIZE:-512M}"

BOOTABLE_DOCKER_BUILD_ARGS=()
BOOTABLE_BUILD_NOCACHE="${BOOTABLE_BUILD_NOCACHE:-0}"
BOOTABLE_DOCKER_TOOLCHAIN_TAG="jamesits/bootable:toolchain-latest"
BOOTABLE_DOCKER_DEFAULT_PLATFORM="linux/amd64"

# ISA-specific config
BOOTABLE_PART_TYPE_GUID_ROOT="4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709"

# Serial console
BOOTABLE_CAVEAT_SERIAL_CONSOLE="1"
