# Linux Image Builder

Docker-based universal Linux image builder.

## Prerequisites

Packages:
- Docker (with buildx support)
- Git

Host OS assumptions:
- Runs SystemD and udevd
- For building CentOS 6 images: `vsyscall=emulate` in kernel command line
