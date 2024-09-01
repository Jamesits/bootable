#!/usr/bin/env bash
set -Eeuo pipefail

DISK="$(realpath "$2")"
# rm -rf /tmp/lib-smoke-test.qcow2
# qemu-img create -f qcow2 -b "${DISK}" -F raw /tmp/lib-smoke-test.qcow2

if [[ "$1" == "efi" ]]; then
    qemu-system-x86_64 -no-user-config -nodefaults -msg timestamp=on -snapshot \
        -machine q35,accel=kvm -nographic -serial mon:stdio \
        -cpu host -smp 4 -m 6144 -net nic -net user \
        -drive "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/x64/OVMF_CODE.fd" \
        -drive "file=${DISK},format=raw,index=0,media=disk"
else
    qemu-system-x86_64 -no-user-config -nodefaults -msg timestamp=on -snapshot \
        -machine q35,accel=kvm -nographic -serial mon:stdio \
        -cpu host -smp 4 -m 6144 -net nic -net user \
        -drive "id=disk,file=${DISK},if=none,format=raw" \
        -device "ahci,id=ahci" \
        -device "ide-hd,drive=disk,bus=ahci.0"
fi
