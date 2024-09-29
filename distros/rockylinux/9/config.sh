#!/hint/bash
# shellcheck disable=SC1090,SC1091 # do not warn for external scripts
# shellcheck disable=SC2034 # do not check for unused variables

BOOTABLE_DOCKER_BUILD_ARGS+=(
    "--label=bootable.plugin.bootloader.grub2.prefix=grub2"
    "--label=bootable.plugin.bootloader.grub2.distro-efi=rocky"
    "--label=bootable.plugin.bootloader.grub2.dnf-secure-boot=1"
)
BOOTABLE_SOURCE_IMAGE="docker.io/library/rockylinux:9"
