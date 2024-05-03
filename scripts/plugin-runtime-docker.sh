#!/hint/bash

export DOCKER_BUILDKIT=1
DLIB_DOCKER_BUILD_ARG+=(
    # BuildKit cache
    "--build-arg"
    "BUILDKIT_INLINE_CACHE=1"

    # Proxy config
    "--build-arg"
    "http_proxy"
    "--build-arg"
    "https_proxy"
    "--build-arg"
    "all_proxy"
    "--build-arg"
    "no_proxy"

    # Dlib config
    "--build-arg"
    "DLIB_SOURCE_IMAGE"
    "--build-arg"
    "DLIB_BUILD_FLAVOR"
)

# Usage: $0 <context-dir> <file> <output-tar>
dlib::container::build::tar() {
    local REL_FILE
    REL_FILE=$(realpath --relative-to="$1" "$2")
    docker build --file="$REL_FILE" --output="type=tar,dest=$3" "${DLIB_DOCKER_BUILD_ARG[@]}" -- "$1"
    return $?
}

# Usage: $0 <context-dir> <file> <output-tag>
dlib::container::build::image() {
    local REL_FILE
    REL_FILE=$(realpath --relative-to="$1" "$2")
    docker build --file="$REL_FILE" --tag="$3" "${DLIB_DOCKER_BUILD_ARG[@]}" -- "$1"
    return $?
}

# Usage: $0 <tag> <working-dir> <cmd> [args...]
dlib::container::exec() {
    local TAG=$1
    shift
    local PWD=$1
    shift

    docker run --rm --privileged --hostname="$(uname -n)" --volume="$PWD:$PWD" --volume="/dev:/dev" --workdir="$PWD" -- "$TAG" "$@"
    return $?
}
