#!/hint/bash

export DOCKER_BUILDKIT=1
BOOTABLE_DOCKER_BUILD_ARGS+=(
    "--pull"

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

    # bootable config
    "--build-arg"
    "BOOTABLE_SOURCE_IMAGE"
)

__docker_export() {
    export DOCKER_DEFAULT_PLATFORM="${BOOTABLE_DOCKER_DEFAULT_PLATFORM}"
    export BOOTABLE_SOURCE_IMAGE
}

# Usage: $0 <context-dir> <file> <output-tag>
bootable::container::build::image() {
    local FILE
    FILE=$(readlink -e "$2") # one day suddenly Docker stopped recoginzing symlinks
    __docker_export
    docker build --file="$FILE" --tag="$3" "${BOOTABLE_DOCKER_BUILD_ARGS[@]}" -- "$1"
    return $?
}

# Usage: $0 <tag> <working-dir> <cmd> [args...]
bootable::container::exec() {
    local TAG=$1
    shift
    local PWD=$1
    shift

    __docker_export
    docker run --interactive --rm --privileged --hostname="$(uname -n)" --volume="$PWD:$PWD" --volume="/dev:/dev" --workdir="$PWD" -- "$TAG" "$@"
    return $?
}

# Usage: $0 <tag> <output-tar>
bootable::container::export::tar() {
    local TEMP_CONTAINER
    TEMP_CONTAINER=$(docker container create "$1")

    __docker_export
    docker export "${TEMP_CONTAINER}" --output="$2"
    docker container rm "${TEMP_CONTAINER}"
    return 0
}

# Get the value of a label
# Usage: $0 <tag> <label> <default-value>
bootable::container::label::get() {
    __docker_export
    docker image inspect "$1" | jq -r ".[0].Config.Labels[\"$2\"] | select (.!=null)" | grep . || printf '%s\n' "$3"
}
