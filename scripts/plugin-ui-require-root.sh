#!/hint/bash
# Reject execution if the script is not running as root
if [ "$EUID" -ne 0 ]; then
    >&2 printf "[!] This script must be run with root privileges.\n"
    exit 255
fi
