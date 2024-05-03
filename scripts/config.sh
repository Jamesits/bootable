#!/hint/bash
# shellcheck disable=SC2034 # do not check for unused variables

# Scratch directory location
LIB_GLOBAL_TMP_DIR="${LIB_PROJECT_ROOT}/tmp"

# OS image disk size
LIB_DISK_SIZE="${LIB_DISK_SIZE:-4G}"
LIB_EFI_PARTITION_SIZE="${LIB_EFI_PARTITION_SIZE:-256M}"
LIB_SWAP_PARTITION_SIZE="${LIB_SWAP_PARTITION_SIZE:-512M}"

LIB_DOCKER_BUILD_ARGS=()
LIB_BUILD_NOCACHE="${LIB_BUILD_NOCACHE:-0}"
LIB_DOCKER_TOOLCHAIN_TAG="localhost/lib/toolchain:latest"
