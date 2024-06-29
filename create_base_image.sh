#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091 # do not warn for external scripts
set -Eeuo pipefail

BOOTABLE_PROJECT_ROOT="$(cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd)"
BOOTABLE_PLUGINS_DIR="${BOOTABLE_PROJECT_ROOT}/scripts"
. "${BOOTABLE_PLUGINS_DIR}/config.sh"
. "${BOOTABLE_PLUGINS_DIR}/common.sh"

# args
BOOTABLE_DISTRO="${BOOTABLE_DISTRO:-$1}"
BOOTABLE_DOCKER_TAG="${BOOTABLE_DOCKER_TAG:-$2}"
BOOTABLE_FLAVOR="${BOOTABLE_FLAVOR:-$3}"
>&2 printf "[i] Using distro %s\n" "${BOOTABLE_DISTRO}"

# Image-specific overrides
. "${BOOTABLE_DISTROS_DIR}/${BOOTABLE_DISTRO}/config.sh"

# Build the base image
>&2 printf "[*] Build: %s...\n" "${BOOTABLE_DISTRO}"
bootable::container::build::image "${BOOTABLE_PROJECT_ROOT}" "${BOOTABLE_DISTROS_DIR}/${BOOTABLE_DISTRO}/Containerfile.${BOOTABLE_FLAVOR}" "${BOOTABLE_DOCKER_TAG}"
