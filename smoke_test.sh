#!/usr/bin/env bash
set -Eeuo pipefail

rm -rf /tmp/lib-smoke-test.qcow2
qemu-img create -f qcow2 -b "$(realpath "$2")" -F raw /tmp/lib-smoke-test.qcow2

if [[ "$1" == "efi" ]]; then
    qemu-system-x86_64 -no-user-config -nodefaults -msg timestamp=on \
        -machine q35,accel=kvm -nographic -serial mon:stdio \
        -cpu host -smp 4 -m 6144 -net nic -net user \
        -drive "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/x64/OVMF_CODE.fd" \
        -drive "file=/tmp/lib-smoke-test.qcow2,format=qcow2,index=0,media=disk"
else
    qemu-system-x86_64 -no-user-config -nodefaults -msg timestamp=on \
        -machine q35,accel=kvm -nographic -serial mon:stdio \
        -cpu host -smp 4 -m 6144 -net nic -net user \
        -drive id=disk,file=/tmp/lib-smoke-test.qcow2,if=none,format=qcow2 \
        -device ahci,id=ahci \
        -device ide-hd,drive=disk,bus=ahci.0
fi
