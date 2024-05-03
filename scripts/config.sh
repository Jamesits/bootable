#!/hint/bash
# shellcheck disable=SC2034 # do not check for unused variables

# Scratch directory location
DLIB_GLOBAL_TMP_DIR="${DLIB_PROJECT_ROOT}/tmp"

# OS image disk size
DLIB_DISK_SIZE="${DLIB_DISK_SIZE:-4G}"
DLIB_EFI_PARTITION_SIZE="${DLIB_EFI_PARTITION_SIZE:-256M}"
DLIB_SWAP_PARTITION_SIZE="${DLIB_SWAP_PARTITION_SIZE:-512M}"

DLIB_DOCKER_BUILD_ARGS=()
DLIB_BUILD_NOCACHE="${DLIB_BUILD_NOCACHE:-0}"
DLIB_DOCKER_TOOLCHAIN_TAG="localhost/lib/toolchain:latest"
