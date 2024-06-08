#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091 # do not warn for external scripts
set -Eeuo pipefail

BOOTABLE_PROJECT_ROOT="$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)"
BOOTABLE_TOOLCHAIN_DIR="${BOOTABLE_PROJECT_ROOT}/toolchain"
. "${BOOTABLE_PLUGINS_DIR}/config.sh"
. "${BOOTABLE_PLUGINS_DIR}/common.sh"

# Build the toolchain
>&2 printf "[*] Build: toolchain...\n"
bootable::container::build::image "${BOOTABLE_PROJECT_ROOT}" "${BOOTABLE_TOOLCHAIN_DIR}/Containerfile" "${BOOTABLE_DOCKER_TOOLCHAIN_TAG}"
