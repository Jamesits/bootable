#!/hint/bash

bootable::plugin::disk::create() {
    bootable::toolchain sfdisk --force "$1" <<EOF
label: dos
unit: sectors
sector-size: 512

noop1 : start=        2048, size=        4096, type=83
noop2 : start=        6144, size=      524288, type=ef
noop3 : start=      530432, size=     1048576, type=82
noop4 : start=     1579008, size=     6809600, type=83

EOF
    bootable::toolchain sfdisk -l "$1"
}
