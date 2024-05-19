#!/hint/bash

dlib::plugin::disk::create() {
    # Note: roughly follows the discoverable partitions specification while compatible with both EFI and legacy boot
    toolchain sgdisk --zap-all --set-alignment=2048 --align-end --move-second-header --disk-guid="R" \
        -n "1:0:+2M"                          -c "1:grub"  -t "1:21686148-6449-6E6F-744E-656564454649" \
        -n "2:0:+${DLIB_EFI_PARTITION_SIZE}"  -c "2:EFI"   -t "2:C12A7328-F81F-11D2-BA4B-00A0C93EC93B" \
        -n "3:0:+${DLIB_SWAP_PARTITION_SIZE}" -c "3:SWAP"  -t "3:0657FD6D-A4AB-43C4-84E5-0933C84B4F4F" \
        -n "4:0:0"                            -c "4:Linux" -t "4:${DLIB_PART_TYPE_GUID_ROOT}" \
        "$1"
    toolchain sgdisk --info "$1"
}
