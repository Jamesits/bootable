# Bootable

Docker-based universal Linux image builder.

## Prerequisites

Packages:
- Docker (with buildx support)
- Git

Host OS assumptions:
- Runs SystemD and udevd
- For building CentOS 6 images: `vsyscall=emulate` in kernel command line

## Building

### Building the Final Image

```shell
sudo ./build.sh path/to/config/dir path/to/final/disk.img
```

Example configs can be found in `tests` dir.

To fire up a VM to test the new image: `./smoke_test.sh <efi/legacy> path/to/final/disk.img`

### Selfhosting the Toolchain

Normally you can pull pre-built toolchain images off the Docker Hub, but in case that you want to build it yourself:

```
sudo ./create_toolchain_image.sh

# for distros needed
DISTRO="debian/bookworm" # should be a directory under distros dir
TAG="jamesits/bootable:base-${DISTRO//\//-}-grub2-latest"
sudo ./create_base_image.sh "$distro" "${TAG}" "grub2"
```

## Known Issues

- Ubuntu bionic: EFI boot does not work due to bundled GRUB2 does not recognize EXT4 partition
- CentOS 6: GRUB does not install for now
- Alpine Linux: currently does not boot
