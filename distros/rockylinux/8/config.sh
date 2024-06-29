#!/hint/bash
# shellcheck disable=SC1090,SC1091 # do not warn for external scripts
# shellcheck disable=SC2034 # do not check for unused variables

BOOTABLE_DOCKER_BUILD_ARGS+=(
    "--label=bootable.plugin.bootloader.grub2.id=grub2"
    "--label=bootable.plugin.bootloader.grub2.efi-id=rocky"
    "--label=bootable.plugin.bootloader.grub2.dnf-secure-boot=1"
)
BOOTABLE_SOURCE_IMAGE="registry.hub.docker.com/library/rockylinux:8"
