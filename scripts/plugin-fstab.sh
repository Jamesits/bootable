#!/hint/bash
# Notes:
# - set / to rw, otherwise if kernel has `ro` set in its command line, the boot process will go wrong
# - mount /boot/efi (it doesn't auto mount on legacy boot systems even if we adhere to the discoverable partitions specification)
# - set up swap partition

dlib::plugin::fstab::generate() {
    cat > "${DLIB_MOUNT_ROOT}/etc/fstab" <<EOF
UUID=$(toolchain blkid -s UUID -o value "${DLIB_DISK_LOOPBACK_DEVICE}p4") /         ext4    defaults,rw,noatime,nodiratime  0 0
UUID=$(toolchain blkid -s UUID -o value "${DLIB_DISK_LOOPBACK_DEVICE}p2") /boot/efi vfat    defaults,rw                     0 0
UUID=$(toolchain blkid -s UUID -o value "${DLIB_DISK_LOOPBACK_DEVICE}p3") swap      swap    defaults                        0 0
EOF
}