# Linux Image Builder

Docker-based universal Linux image builder.

## Prerequisites

Packages:
- Docker (with buildx support)
- Git

Host OS assumptions:
- Runs SystemD and udevd
- For building CentOS 6 images: `vsyscall=emulate` in kernel command line

## Building

```shell
sudo ./build.sh <distro>/<version>
```

## Known Issues

- Ubuntu bionic: EFI boot does not work due to bundled GRUB2 does not recognize EXT4 partition
- CentOS 6: GRUB does not install for now
- Alpine Linux: currently does not boot
