#!/hint/bash

export DOCKER_BUILDKIT=1
LIB_DOCKER_BUILD_ARG+=(
    "--build-arg"
    "BUILDKIT_INLINE_CACHE=1"
)

# Usage: $0 <context-dir> <file> <output-tar>
container::build::tar() {
    local REL_FILE
    REL_FILE=$(realpath -s --relative-to="$1" "$2")
    docker build --file="$REL_FILE" --output="type=tar,dest=$3" -- "$1"
    return $?
}

# Usage: $0 <context-dir> <file> <output-tag>
container::build::image() {
    local REL_FILE
    REL_FILE=$(realpath -s --relative-to="$1" "$2")
    docker build --file="$REL_FILE" --tag="$3" -- "$1"
    return $?
}

# Usage: $0 <tag> <working-dir> <cmd> [args...]
container::exec() {
    local TAG=$1
    shift
    local PWD=$1
    shift

    docker run --rm --privileged --hostname="$(uname -n)" --volume="$PWD:$PWD" --volume="/dev:/dev" --workdir="$PWD" -- "$TAG" "$@"
    return $?
}
