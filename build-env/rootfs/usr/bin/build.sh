#!/usr/bin/env bash
# ==============================================================================
#
# Community Hass.io Add-ons: Build Environment
#
# Script for building our cross platform Hass.io Docker images.
#
# ==============================================================================
set -o errexit  # Exit script when a command exits with non-zero status
set -o errtrace # Exit on error inside any functions or sub-shells
set -o nounset  # Exit script on use of an undefined variable
set -o pipefail # Return exit status of the last command in the pipe that failed

# ==============================================================================
# GLOBALS
# ==============================================================================
readonly EX_OK=0                # Successful termination
readonly EX_UNKNOWN=1           # Unknown error occured
readonly EX_CROSS=3             # Failed enabling cross compile features
readonly EX_DOCKER_BUILD=4      # Docker build failed
readonly EX_DOCKER_DIE=5        # Took to long for container to die
readonly EX_DOCKER_PUSH=6       # Failed pushing Docker image
readonly EX_DOCKER_TAG=7        # Failed setting Docker tag
readonly EX_DOCKER_TIMEOUT=8    # Timout starting docker
readonly EX_DOCKERFILE=9        # Dockerfile is missing?
readonly EX_GIT_CLONE=10        # Failed cloning Git repository
readonly EX_GIT=11              # Is this a Git repository?
readonly EX_INVALID_TYPE=12     # Invalid build type
readonly EX_MULTISTAGE=13       # Dockerfile contains multiple stages
readonly EX_NO_ARCHS=14         # No architectures to build
readonly EX_NO_IMAGE_NAME=15    # Missing name of image to build
readonly EX_NOT_EMPTY=16        # Workdirectory is not empty
readonly EX_PRIVILEGES=17       # Not running without --privileged
readonly EX_SUPPORTED=18        # Requested build architecture is not supported
readonly EX_VERSION=19          # Version not found and specified

# Constants
readonly DOCKER_PIDFILE='/var/run/docker.pid' # Docker daemon PID file
readonly DOCKER_TIMEOUT=20  # Wait 20 seconds for docker to start/exit

# Global variables
declare -a BUILD_ARCHS
declare -A BUILD_ARCHS_FROM
declare -A BUILD_ARGS
declare -a EXISTING_ARGS
declare -a EXISTING_LABELS
declare -a SUPPORTED_ARCHS
declare -i DOCKER_PID
declare BUILD_ALL=false
declare BUILD_BRANCH
declare BUILD_DESCRIPTION
declare BUILD_DOC_URL
declare BUILD_FROM
declare BUILD_GIT_URL
declare BUILD_IMAGE
declare BUILD_LABEL_OVERRIDE
declare BUILD_MAINTAINER
declare BUILD_NAME
declare BUILD_PARALLEL
declare BUILD_REF
declare BUILD_REPOSITORY
declare BUILD_TARGET
declare BUILD_TYPE
declare BUILD_URL
declare BUILD_VENDOR
declare BUILD_VERSION
declare DOCKER_CACHE
declare DOCKER_PUSH
declare DOCKER_SQUASH
declare DOCKER_TAG_LATEST
declare DOCKER_TAG_TEST
declare DOCKERFILE
declare TRAPPED
declare USE_GIT

# Defaults values
BUILD_ARCHS=()
BUILD_BRANCH='master'
BUILD_LABEL_OVERRIDE=false
BUILD_PARALLEL=false
BUILD_TARGET=$(pwd)
DOCKER_CACHE=true
DOCKER_PID=9999999999
DOCKER_PUSH=false
DOCKER_TAG_LATEST=false
DOCKER_TAG_TEST=false
TRAPPED=false
USE_GIT=false

# ==============================================================================
# UTILITY
# ==============================================================================

# ------------------------------------------------------------------------------
# Displays a simple program header
#
# Arguments:
#   None
# Returns:
#   None
# ------------------------------------------------------------------------------
display_banner() {
    echo '---------------------------------------------------------'
    echo 'Community Hass.io Add-ons: Hass.io cross platform builder'
    echo '---------------------------------------------------------'
}

# ------------------------------------------------------------------------------
# Displays a error message and is able to terminate te script execution
#
# Arguments:
#   $1 Error message
#   $2 Exit code, script will continue execution when omitted
# Returns:
#   None
# ------------------------------------------------------------------------------
display_error_message() {
  local status=${1}
  local exitcode=${2:-0}

  echo >&2
  echo " !     ERROR: ${status}"
  echo >&2

  if [[ ${exitcode} -ne 0 ]]; then
    exit "${exitcode}"
  fi
}

# ------------------------------------------------------------------------------
# Displays a notice
#
# Arguments:
#   $* Notice message to display
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
display_notice_message() {
  local status=$*

  echo
  echo "NOTICE: ${status}"
  echo
}

# ------------------------------------------------------------------------------
# Displays a status message
#
# Arguments:
#   $* Status message to display
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
display_status_message() {
  local status=$*

  echo "-----> ${status}"
}

# ------------------------------------------------------------------------------
# Displays the help of this program
#
# Arguments:
#   $1 Exit code
#   $2 Error message
# Returns:
#   None
# ------------------------------------------------------------------------------
display_help () {
    local exit_code=${1:-${EX_OK}}
    local status=${2:-}

    [[ ! -z "${status}" ]] && display_error_message "${status}"

    cat << EOF
Options:

    -h, --help
        Display this help and exit.

    -t, --target <directory>
        The target directory containing the Dockerfile to build.
        Defaults to the current working directory (.).

    -r, --repository <url>
        Build using a remote repository.
        Note: use --target to specify a subdirectory within the repository.

    -b, --branch <name>
        When using a remote repository, build this branch.
        Defaults to master.

    ------ Build Architectures ------

    --aarch64
        Build for aarch64 (arm 64 bits) architecture.

    --amd64
        Build for amd64 (intel/amd 64 bits) architecture.

    --armhf
        Build for armhf (arm 32 bits) architecture.

    --i386
        Build for i386 (intel/amd 32 bits) architecture.

    -a, --all
        Build for all architectures.
        Same as --aarch64 --amd64 --armhf --i386.
        If a limited set of supported architectures is defined in
        a configuration file, that list is still honored when using
        this flag.

    ------ Build base images ------

    These build options will override any value in your 'build.json' file.

    --aarch64-from <image>
        Use a custom base image when building for aarch64.
        e.g. --aarch64-image "homeassistant/aarch64-base".
        Note: This overrides the --from flag for this architecture.

    --amd64-from <image>
        Use a custom base image when building for amd64.
        e.g. --amd64-image "homeassistant/amd64-base".
        Note: This overrides the --from flag for this architecture.

    --armhf-from <image>
        Use a custom base image when building for armhf.
        e.g. --armhf-image "homeassistant/armhf-base".
        Note: This overrides the --from flag for this architecture.

    --i386-from <image>
        Use a custom base image when building for i386.
        e.g. --i386-image "homeassistant/i386-image".
        Note: This overrides the --from flag for this architecture.

    -f, --from <image>
        Use a custom base image when building.
        Use '{arch}' as a placeholder for the architecture name.
        e.g., --from "homeassistant/{arch}-base"

    ------ Build output ------

    -i, --image <image>
        Specify a name for the output image.
        In case of building an add-on, this will override the name
        as set in the add-on configuration file. Use '{arch}' as an
        placeholder for the architecture name.
        e.g., --image "myname/{arch}-myaddon"

    -l, --tag-latest
        Tag Docker build as latest.
        Note: This is automatically done when on the latest Git tag AND
              using the --git flag.

    --tag-test
        Tag Docker build as test.
        Note: This is automatically done when using the --git flag.

    -p, --push
        Upload the resulting build to Docker hub.

    ------ Build options ------

    --arg <key> <value>
        Pass additional build arguments into the Docker build.
        This option can be repeated for multiple key/value pairs.

    -c, --no-cache
        Disable build from cache.

    --parallel
        Parallelize builds. Build all requested architectures in parallel.
        While this speeds up the process tremendously, it is, however, more
        prone to errors caused by system resources.

    --squash
        Squash the layers of the resulting image to the parent image, and
        still allows for base image reuse. Use with care; you can not use the
        image for caching after squashing!
        Note: This feature is still marked "Experimental" by Docker.

    ------ Build meta data ------

    -g, --git
        Use Git for version tags instead of the add-on configuration file.
        It also manages 'latest' and 'test' tags.
        Note: This will ONLY work when your Git repository only contains
              a single add-on or other Docker container!

    -n, --name <name>
        Name or title of the thing that is being built.

    -d, --description <description>
        Description of the thing that is being built.

    --vendor <vendor>
        The name of the vendor providing the thing that is being built.

    -m, --maintainer, --author <author>
        Name of the maintainer. MUST be in "My Name <email@example.com>" format.
        e.g., "Franck Nijhof <frenck@addons.community>"

    -u, --url <ur>
        URL to the homepage of the thing that is built.
        Note: When building add-ons; this will override the setting from
              the configuration file.

    -c, --doc-url <url>
        URL to the documentation of the thing that is built.
        When omitted, the value of --url will be used.

    --git-url <url>
        The URL to the Git repository (e.g., GitHub).
        When omitted, the value is detected using Git or the add-on url
        configuration value will be used.

    -o, --override
        Always override Docker labels.
        The normal behavior of the builder is to only add a label when it is
        not found in the Dockerfile. This flag enforces to override all label
        values.

EOF

    exit "${exit_code}"
}

# ==============================================================================
# SCRIPT LOGIC
# ==============================================================================

# ------------------------------------------------------------------------------
# Cleanup function after execution is of the script is stopped. (trap)
#
# Arguments:
#   $1 Exit code
# Returns:
#   None
# ------------------------------------------------------------------------------
cleanup_on_exit() {
    local exit_code=${1}

    # Prevent double cleanup. Thx Bash :)
    if [[ "${TRAPPED}" != true ]]; then
        TRAPPED=true
        docker_stop_daemon
        docker_disable_crosscompile
        [[ "${exit_code}" -ne 0 ]] \
            && display_error_message "Build failed, exited with errors"
    fi

    exit "${exit_code}"
}

# ------------------------------------------------------------------------------
# Clones a remote Git repository to a local working dir
#
# Arguments:
#   None
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
clone_repository() {
    display_status_message 'Cloning remote Git repository'

    [[ "$(ls -A ".")" ]] && display_error_message \
        '/docker mount is in use already, while requesting a repository' \
        "${EX_NOT_EMPTY}"

    git clone \
        --depth 1 --single-branch "${BUILD_REPOSITORY}" \
        -b "${BUILD_BRANCH}" "$(pwd)" \
        || display_error_message 'Failed cloning requested Git repository' \
            "${EX_GIT_CLONE}"

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Start the Docker build
#
# Arguments:
#   $1 Architecture to build
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
docker_build() {
    local -a build_args
    local arch=${1}
    local build_date
    local dockerfile
    local from
    local image

    display_status_message 'Running Docker build'

    dockerfile="${DOCKERFILE//\{arch\}/${arch}}"
    image="${BUILD_IMAGE//\{arch\}/${arch}}"
    build_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    build_args+=(--pull)
    build_args+=(--tag "${image}:${BUILD_VERSION}")

    [[ "${DOCKER_SQUASH}" = true ]] && build_args+=(--squash)

    if [[ ! -z "${BUILD_ARCHS_FROM[${arch}]:-}" ]]; then
        build_args+=(--build-arg "BUILD_FROM=${BUILD_ARCHS_FROM[${arch}]}")
    else
        from="${BUILD_FROM//\{arch\}/${arch}}"
        build_args+=(--build-arg "BUILD_FROM=${from}")
    fi

    if [[ "${DOCKER_CACHE}" = true ]]; then
        build_args+=(--cache-from "${image}:latest")
    else
        build_args+=(--no-cache)
    fi

    [[ "${EXISTING_ARGS[*]}" = *"BUILD_DESCRIPTION"* ]] \
        && build_args+=(--build-arg "BUILD_DESCRIPTION=${BUILD_DESCRIPTION}")

    [[ "${EXISTING_ARGS[*]}" = *"BUILD_GIT_URL"* ]] \
        && build_args+=(--build-arg "BUILD_GIT_URL=${BUILD_GIT_URL}")

    [[ "${EXISTING_ARGS[*]}" = *"BUILD_MAINTAINER"* ]] \
        && build_args+=(--build-arg "BUILD_MAINTAINER=${BUILD_MAINTAINER}")

    [[ "${EXISTING_ARGS[*]}" = *"BUILD_NAME"* ]] \
        && build_args+=(--build-arg "BUILD_NAME=${BUILD_NAME}")

    [[ "${EXISTING_ARGS[*]}" = *"BUILD_REF"* ]] \
        && build_args+=(--build-arg "BUILD_REF=${BUILD_REF}")

    [[ "${EXISTING_ARGS[*]}" = *"BUILD_TYPE"* ]] \
        && build_args+=(--build-arg "BUILD_TYPE=${BUILD_TYPE}")

    [[ "${EXISTING_ARGS[*]}" = *"BUILD_URL"* ]] \
        && build_args+=(--build-arg "BUILD_URL=${BUILD_URL}")

    [[ "${EXISTING_ARGS[*]}" = *"BUILD_DOC_URL"* ]] \
        && build_args+=(--build-arg "BUILD_DOC_URL=${BUILD_DOC_URL}")

    [[ "${EXISTING_ARGS[*]}" = *"BUILD_VENDOR"* ]] \
        && build_args+=(--build-arg "BUILD_VENDOR=${BUILD_VENDOR}")

    [[ "${EXISTING_ARGS[*]}" = *"BUILD_VERSION"* ]] \
        && build_args+=(--build-arg "BUILD_VERSION=${BUILD_VERSION}")

    [[ "${EXISTING_ARGS[*]}" = *"BUILD_ARCH"* ]] \
        && build_args+=(--build-arg "BUILD_ARCH=${arch}")

    [[ "${EXISTING_ARGS[*]}" = *"BUILD_DATE"* ]] \
        && build_args+=(--build-arg "BUILD_DATE=${build_date}")

    for arg in "${!BUILD_ARGS[@]}"; do
        [[ "${EXISTING_ARGS[*]}" = *"${arg}"* ]] \
            && build_args+=(--build-arg "${arg}=${BUILD_ARGS[$arg]}")
    done

    IFS=' '
    display_status_message "docker build ${build_args[*]}"

    (
        docker-context-streamer "${BUILD_TARGET}" <<< "$dockerfile" \
        | docker build "${build_args[@]}" -
    ) || display_error_message 'Docker build failed' "${EX_DOCKER_BUILD}"

    display_status_message 'Docker build finished'
    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Disables Docker's cross compiler features (qemu)
#
# Arguments:
#   None
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
docker_disable_crosscompile() {
    display_status_message 'Disabling cross compile features'

    if [[ -f /proc/sys/fs/binfmt_misc/status ]]; then
        umount binfmt_misc || display_error_message \
            'Failed disabling cross compile features!' "${EX_CROSS}"
    fi

    (
        update-binfmts --disable qemu-arm && \
        update-binfmts --disable qemu-aarch64
    ) || display_error_message 'Failed disabling cross compile features!' \
        "${EX_CROSS}"

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Enables Docker's cross compiler features (qemu)
#
# Arguments:
#   None
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
docker_enable_crosscompile() {
    display_status_message 'Enabling cross compile features'
    (
        mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc && \
        update-binfmts --enable qemu-arm && \
        update-binfmts --enable qemu-aarch64
    ) || display_error_message 'Failed enabling cross compile features!' \
        "${EX_CROSS}"

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Push Docker build result to DockerHub
#
# Arguments:
#   $1 Architecture
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
docker_push() {
    local arch=${1}
    local image

    image="${BUILD_IMAGE//\{arch\}/${arch}}"

    display_status_message 'Pushing Docker image'
    docker push "${image}:${BUILD_VERSION}" \
        || display_error_message 'Docker push failed' "${EX_DOCKER_PUSH}";
    display_status_message 'Push finished'

    if [[ "${DOCKER_TAG_LATEST}" = true ]]; then
        display_status_message 'Pushing Docker image tagged as latest'

        docker push "${image}:latest" \
            || display_error_message 'Docker push failed' "${EX_DOCKER_PUSH}"

        display_status_message 'Push finished'
    fi

    if [[ "${DOCKER_TAG_TEST}" = true ]]; then
        display_status_message 'Pushing Docker image tagged as test'

        docker push "${image}:test" \
            || display_error_message 'Docker push failed' "${EX_DOCKER_PUSH}"

        display_status_message 'Push finished'
    fi

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Starts the Docker daemon
#
# Arguments:
#   None
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
docker_start_daemon() {
    local time_start
    local time_end

    display_status_message 'Starting the Docker daemon'

    dockerd --experimental=true > /dev/null 2>&1 &
    DOCKER_PID=$!

    display_status_message 'Waiting for Docker to initialize...'
    time_start=$(date +%s)
    time_end=$(date +%s)
    until docker info >/dev/null 2>&1; do
        if [ $((time_end - time_start)) -le ${DOCKER_TIMEOUT} ]; then
            sleep 1
            time_end=$(date +%s)
        else
            display_error_message \
                'Timeout while waiting for Docker to come up' \
                "${EX_DOCKER_TIMEOUT}"
        fi
    done
    disown
    display_status_message 'Docker is initialized'

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Stops Docker daemon
#
# Arguments:
#   None
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
docker_stop_daemon() {
    local time_start
    local time_end

    display_status_message 'Stopping the Docker daemon'

    if [[ "${DOCKER_PID}" -ne 0 ]] \
        && kill -0 "${DOCKER_PID}" 2> /dev/null \
    ; then
        kill "${DOCKER_PID}"

        time_start=$(date +%s)
        time_end=$(date +%s)
        while kill -0 "${DOCKER_PID}" 2> /dev/null; do
            if [ $((time_end - time_start)) -le ${DOCKER_TIMEOUT} ]; then
                sleep 1
                time_end=$(date +%s)
            else
                display_error_message \
                    'Timeout while waiting for Docker to shut down' \
                    "${EX_DOCKER_TIMEOUT}"
            fi
        done

        display_status_message 'Docker daemon has been stopped'
    else
        display_status_message 'Docker daemon was already stopped'
    fi

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Places 'latest'/'test' tag(s) onto the current build result
#
# Arguments:
#   $1 Architecture
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
docker_tag() {
    local arch=${1}
    local image

    image="${BUILD_IMAGE//\{arch\}/${arch}}"

    if [[ "${DOCKER_TAG_LATEST}" = true ]]; then
        display_status_message 'Tagging images as latest'
        docker tag "${image}:${BUILD_VERSION}" "${image}:latest" \
            || display_error_message 'Setting latest tag failed' \
                "${EX_DOCKER_TAG}"
    fi

    if [[ "${DOCKER_TAG_TEST}" = true ]]; then
        display_status_message 'Tagging images as test'
        docker tag "${image}:${BUILD_VERSION}" "${image}:test" \
            || display_error_message 'Setting test tag failed' \
                "${EX_DOCKER_TAG}"
    fi

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Try to pull latest version of the current image to use as cache
#
# Arguments:
#   $1 Architecture
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
docker_warmup_cache() {
    local arch=${1}
    local image

    image="${BUILD_IMAGE//\{arch\}/${arch}}"
    display_status_message 'Warming up cache'

    if ! docker pull "${image}:latest" 2>&1; then
        display_notice_message 'Cache warmup failed, continuing without it'
        DOCKER_CACHE=false
    fi

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Tries to fetch information from the add-on config file.
#
# Arguments:
#   $1 JSON file to parse
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
get_info_json() {
    local archs
    local args
    local jsonfile=$1
    local squash

    display_status_message "Loading information from ${jsonfile}"

    [[ -z "${BUILD_VERSION:-}" ]] \
        && BUILD_VERSION=$(jq -r '.version' "${jsonfile}")

    [[ -z "${BUILD_IMAGE:-}" ]] \
        && BUILD_IMAGE=$(jq -r '.image // empty' "${jsonfile}")

    IFS=
    archs=$(jq -r '.arch // empty | .[]' "${jsonfile}")
    while read -r arch; do
        SUPPORTED_ARCHS+=("${arch}")
    done <<< "${archs}"

    IFS=
    archs=$(jq -r '.build_from // empty | keys[]' "${jsonfile}")
    while read -r arch; do
        if [[ ! -z "${arch}"
            && -z "${BUILD_ARCHS_FROM["${arch}"]:-}"
        ]]; then
            BUILD_ARCHS_FROM[${arch}]=$(jq -r \
                ".build_from | .${arch}" "${jsonfile}")
        fi
    done <<< "${archs}"

    if [[ -z "${DOCKER_SQUASH:-}" ]]; then
        squash=$(jq -r '.squash | not | not' "${jsonfile}")
        [[ "${squash}" = true ]] && DOCKER_SQUASH=true
        [[ "${squash}" = false ]] && DOCKER_SQUASH=false
    fi

    IFS=
    args=$(jq -r '.args // empty | keys[]' "${jsonfile}")
    while read -r arg; do
        if [[ ! -z "${arg}"
            && -z "${BUILD_ARGS["${arch}"]:-}"
        ]]; then
            BUILD_ARGS[${arg}]=$(jq -r \
                ".args | .${arg}" "${jsonfile}")
        fi
    done <<< "${args}"

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Tries to fetch information from existing Dockerfile
#
# Arguments:
#   None
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
get_info_dockerfile() {
    local from
    local args
    local labels
    local json

    display_status_message 'Collecting information from Dockerfile'

    DOCKERFILE=$(<"${BUILD_TARGET}/Dockerfile")
    json=$(dockerfile2json "${BUILD_TARGET}/Dockerfile")

    if [[
        ! -z $(jq -r '.[] | select(.cmd=="arg") // empty' <<< "${json}")
    ]]; then
        args=$(jq -r '.[] | select(.cmd=="arg") | .value | .[]' \
            <<< "${json}")

        IFS=
        while read -r arg; do
            if [[ "${arg}" = *'='* ]]; then
                value="${arg#*=}"
                value="${value%\"}"
                value="${value#\"}"
                arg="${arg%%=*}"
            else
                value=''
            fi
            EXISTING_ARGS+=("${arg}")

            if [[ ! -z "$value" ]]; then
                case $arg in
                    BUILD_FROM)
                        [[ -z "${BUILD_FROM:-}" ]] && BUILD_FROM="${value}"
                        ;;
                    BUILD_NAME)
                        [[ -z "${BUILD_NAME:-}" ]] && BUILD_NAME="${value}"
                        ;;
                    BUILD_DESCRIPTION)
                        [[ -z "${BUILD_DESCRIPTION:-}" ]] \
                            && BUILD_DESCRIPTION="${value}"
                        ;;
                    BUILD_URL)
                        [[ -z "${BUILD_URL:-}" ]] && BUILD_URL="${value}"
                        ;;
                    BUILD_GIT_URL)
                        [[ -z "${BUILD_GIT_URL:-}" ]] \
                            && BUILD_GIT_URL="${value}"
                        ;;
                    BUILD_VENDOR)
                        [[ -z "${BUILD_VENDOR:-}" ]] && BUILD_VENDOR="${value}"
                        ;;
                    BUILD_DOC_URL)
                        [[ -z "${BUILD_DOC_URL:-}" ]] \
                            && BUILD_DOC_URL="${value}"
                        ;;
                    BUILD_MAINTAINER)
                        [[ -z "${BUILD_MAINTAINER:-}" ]] \
                            && BUILD_MAINTAINER="${value}"
                        ;;
                    BUILD_TYPE)
                        [[ -z "${BUILD_TYPE:-}" ]] && BUILD_TYPE="${value}"
                        ;;
                esac
            fi
        done <<< "${args}"
    fi

    if [[ -z "${BUILD_MAINTAINER:-}" ]]; then
        BUILD_MAINTAINER=$(jq \
            -r '.[] | select(.cmd=="maintainer") | .value[0]' \
            <<< "${json}")
    fi

    if [[
        ! -z $(jq -r '.[] | select(.cmd=="label") // empty' <<< "${json}")
    ]]; then
        labels=$(jq -r '.[] | select(.cmd=="label") | .value | .[]' \
                    <<< "${json}")
        IFS=
        while read -r label; do
            read -r value
            value="${value%\"}"
            value="${value#\"}"
            EXISTING_LABELS+=("${label}")

            case ${label} in
                org.label-schema.name)
                    [[ -z "${BUILD_NAME:-}" ]] && BUILD_NAME="${value}"
                    ;;
                org.label-schema.description)
                    [[ -z "${BUILD_DESCRIPTION:-}" ]] \
                        && BUILD_DESCRIPTION="${value}"
                    ;;
                org.label-schema.url)
                    [[ -z "${BUILD_URL:-}" ]] && BUILD_URL="${value}"
                    ;;
                org.label-schema.vcs-url)
                    [[ -z "${BUILD_GIT_URL:-}" ]] && BUILD_GIT_URL="${value}"
                    ;;
                org.label-schema.vendor)
                    [[ -z "${BUILD_VENDOR:-}" ]] && BUILD_VENDOR="${value}"
                    ;;
                org.label-schema.usage)
                    [[ -z "${BUILD_DOC_URL:-}" ]] && BUILD_DOC_URL="${value}"
                    ;;
                maintainer)
                    [[ -z "${BUILD_MAINTAINER:-}" ]] \
                        && BUILD_MAINTAINER="${value}"
                    ;;
            esac
        done <<< "${labels}"
    fi

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Tries to fetch information from the Git repository
#
# Arguments:
#   None
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
get_info_git() {
    local ref
    local repo
    local tag
    local url
    local user

    display_status_message 'Collecting information from Git'

    # Is this even a Git repository?
    if ! git -C . rev-parse; then

        if [[ "${USE_GIT}" = true ]]; then
            display_error_message \
                'You have added --git, but is this a Git repo?' \
                "${EX_GIT}"
        fi

        display_notice_message 'This does not Git repository. Skipping.'

        return "${EX_NOT_GIT}"
    fi

    # Is the Git repository dirty? (Uncomitted changes in repository)
    if [[ -z "$(git status --porcelain)" ]]; then

        ref=$(git rev-parse --short HEAD)
        tag=$(git describe --exact-match HEAD --abbrev=0 --tags 2> /dev/null \
                || true)
        BUILD_REF="${ref}"

        # Is current HEAD on a tag and master branch?
        if [[ ! -z "${tag:-}" && "${USE_GIT}" = true ]]; then
            # Is it the latest tag?
            if [[ "$(git describe --abbrev=0 --tags)" = "${tag}" ]]; then
                DOCKER_TAG_LATEST=true
            fi
            BUILD_VERSION="${tag#v}"
        else
            # We are clean, but version is unknown, use commit SHA as version
            BUILD_VERSION="${ref}"
            DOCKER_TAG_TEST=true
        fi

    else
        # Uncomitted changes on the Git repository, dirty!
        BUILD_REF="dirty"
        [[ "${USE_GIT}" = true ]] && BUILD_VERSION="dev"
    fi

    # Try to determine source URL from Git repository
    if [[ -z "${BUILD_GIT_URL:-}" ]]; then
        url=$(git config --get remote.origin.url)
        if [[ "${url}" =~ ^http ]]; then
            BUILD_GIT_URL="${url}"
        elif [[ "${url}" =~ ^git@github.com ]]; then
            user=$(sed -Ene's#git@github.com:([^/]*)/(.*).git#\1#p' \
                <<<"${url}")
            repo=$(sed -Ene's#git@github.com:([^/]*)/(.*).git#\2#p' \
                <<<"${url}")
            BUILD_GIT_URL="https://github.com/${user}/${repo}"
        fi

        if [[ ! -z "${BUILD_GIT_URL:-}" ]] && [[ -z "${BUILD_URL:-}" ]]; then
            BUILD_URL="${BUILD_GIT_URL}"
        fi
    fi

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Parse CLI arguments
#
# Arguments:
#   None
# Returns:
#   None
# ------------------------------------------------------------------------------
parse_cli_arguments() {
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -h|--help)
                display_help
                ;;
            --aarch64)
                BUILD_ARCHS+=(aarch64)
                ;;
            --amd64)
                BUILD_ARCHS+=(amd64)
                ;;
            --armhf)
                BUILD_ARCHS+=(armhf)
                ;;
            --i386)
                BUILD_ARCHS+=(i386)
                ;;
            --all)
                BUILD_ALL=true
                ;;
            --aarch64-from)
                # https://github.com/koalaman/shellcheck/issues/359
                # shellcheck disable=SC2154
                BUILD_ARCHS_FROM['aarch64']="${2}"
                shift
                ;;
            --amd64-from)
                # https://github.com/koalaman/shellcheck/issues/359
                # shellcheck disable=SC2154
                BUILD_ARCHS_FROM['amd64']="${2}"
                shift
                ;;
            --armhf-from)
                # https://github.com/koalaman/shellcheck/issues/359
                # shellcheck disable=SC2154
                BUILD_ARCHS_FROM['armhf']="${2}"
                shift
                ;;
            --i386-from)
                # https://github.com/koalaman/shellcheck/issues/359
                # shellcheck disable=SC2154
                BUILD_ARCHS_FROM['i386']="${2}"
                shift
                ;;
            -f|--from)
                BUILD_FROM="${2}"
                shift
                ;;
            -i|--image)
                BUILD_IMAGE="${2}"
                shift
                ;;
            -l|--tag-latest)
                DOCKER_TAG_LATEST=true
                ;;
            --tag-test)
                DOCKER_TAG_TEST=true
                ;;
            -p|--push)
                DOCKER_PUSH=true
                ;;
            -n|--no-cache)
                DOCKER_CACHE=false
                ;;
            --squash)
                DOCKER_SQUASH=true
                ;;
            --parallel)
                BUILD_PARALLEL=true
                ;;
            -g|--git)
                USE_GIT=true
                ;;
            -n|--name)
                BUILD_NAME="${2}"
                shift
                ;;
            -d|--description)
                BUILD_DESCRIPTION="${2}"
                shift
                ;;
            --vendor)
                BUILD_VENDOR="${2}"
                shift
                ;;
            -m|--maintainer|--author)
                BUILD_MAINTAINER="${2}"
                shift
                ;;
            -u|--url)
                BUILD_URL="${2}"
                shift
                ;;
            -c|--doc-url)
                BUILD_DOC_URL="${2}"
                shift
                ;;
            --git-url)
                BUILD_GIT_URL="${2}"
                shift
                ;;
            -o|--override)
                BUILD_LABEL_OVERRIDE=true
                ;;
            -t|--target)
                BUILD_TARGET="${2}"
                shift
                ;;
            -r|--repository)
                BUILD_REPOSITORY="${2}"
                shift
                ;;
            -v|--version)
                BUILD_VERSION="${2}"
                shift
                ;;
            -b|--branch)
                BUILD_BRANCH="${2}"
                shift
                ;;
            --arg)
                BUILD_ARGS["${2}"]="${3}"
                shift
                shift
                ;;
            *)
                display_help "${EX_UNKNOWN}" "Argument '${1}' unknown."
                ;;
        esac
        shift
    done
}

# ------------------------------------------------------------------------------
# Ensures we have all the information we need to continue building
#
# Arguments:
#   None
# Returns:
#   None
# ------------------------------------------------------------------------------
preflight_checks() {

    display_status_message 'Running preflight checks'

    # In ~80% of the cases running without --privileged will fail
    if ip link add dummy0 type dummy > /dev/null; then
        ip link delete dummy0 > /dev/null
    else
        display_error_message \
            'This build enviroment needs extended privileges (--privileged)' \
            "${EX_PRIVILEGES}"
    fi

    # Do we have anything to build?
    [[ ${#BUILD_ARCHS[@]} -eq 0 ]] && [[ "${BUILD_ALL}" = false ]] \
        && display_help "${EX_NO_ARCHS}" 'No architectures to build'

    # Do we know what version to build?
    [[ -z "${BUILD_VERSION:-}" ]] && display_error_message \
        'No version found and specified. Please use --version' "${EX_VERSION}"

    # Is the requested architecture supported?
    if [[ ${#BUILD_ARCHS[@]} -ne 0 ]] \
        && [[ "${BUILD_ALL}" = false ]] \
        && [[ ! -z "${SUPPORTED_ARCHS[*]:-}" ]];
    then
        for arch in "${BUILD_ARCHS[@]}"; do
            [[ "${SUPPORTED_ARCHS[*]}" = *"${arch}"* ]] || \
                display_error_message \
                    "Requested to build for ${arch}, but it seems like it is not supported" \
                    "${EX_SUPPORTED}"
        done
    fi

    # Are we able to build it?
    if [[ -z "${BUILD_FROM}" ]]; then
        for arch in "${SUPPORTED_ARCHS[@]}"; do
            [[ ! -z $arch && -z "${BUILD_ARCHS_FROM[${arch}]:-}" ]] \
                && display_error_message \
                    "Architucure ${arch}, is missing a image to build from" \
                    "${EX_NO_FROM}"
        done
    fi

    # Multistage Dockerfile?
    [[ $(awk '/^FROM/{a++}END{print a}' <<< "${DOCKERFILE}") -le 1 ]] \
        || display_error_message 'The Dockerfile seems to be multistage!' \
        "${EX_MULTISTAGE}"

    # Do we have an image name?
    [[ -z "${BUILD_IMAGE:-}" ]] \
        && display_error_message 'Missing build image name' \
            "${EX_NO_IMAGE_NAME}"

    # This builder only support addons (and base images for add-ons)
    [[ "${BUILD_TYPE:-}" =~ ^(|addon|base)$ ]] \
        || display_error_message "${BUILD_TYPE:-} is not a valid type." \
            "$EX_INVALID_TYPE"

    # Notices
    [[ -z "${BUILD_NAME:-}" ]] \
        && display_notice_message 'Name not set!'

    [[ -z "${BUILD_DESCRIPTION:-}" ]] \
        && display_notice_message 'Description is not set!'

    [[ -z "${BUILD_VENDOR:-}" ]] \
        && display_notice_message 'Vendor not set!'

    [[ -z "${BUILD_MAINTAINER:-}" ]] \
        && display_notice_message 'Maintainer information is not set!'

    [[ -z "${BUILD_URL:-}" ]] \
        && display_notice_message 'URL is not set!'

    [[ -z "${BUILD_DOC_URL:-}" ]] \
        && display_notice_message 'Documentation url is not set!'

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Prepares all variables for building use
#
# Arguments:
#   None
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
prepare_defaults() {

    display_status_message 'Filling in configuration gaps with defaults'

    [[ -z "${SUPPORTED_ARCHS[*]:-}" ]] \
        && SUPPORTED_ARCHS=(aarch64 amd64 armhf i386)

    if [[ "${BUILD_ALL}" = true ]]; then
        IFS=' '
        BUILD_ARCHS=(${SUPPORTED_ARCHS[*]});
    fi

    [[ -z "${DOCKER_SQUASH:-}" ]] \
        && DOCKER_SQUASH=false

    [[ -z "${BUILD_TYPE:-}" ]] \
        && BUILD_TYPE="addon"

    [[ -z "${BUILD_REF:-}" ]] \
        && BUILD_REF='Unknown'

    [[ -z "${BUILD_URL:-}" && ! -z "${BUILD_REPOSITORY:-}" ]] \
        && BUILD_URL="${BUILD_REPOSITORY}"

    [[ -z "${BUILD_URL:-}" ]] \
        && BUILD_URL=""

    [[ -z "${BUILD_GIT_URL:-}" ]] \
        && BUILD_GIT_URL="${BUILD_URL}"

    [[ -z "${BUILD_DOC_URL:-}" ]] \
        && BUILD_DOC_URL="${BUILD_URL}"

    [[ -z "${BUILD_NAME:-}" ]] \
        && BUILD_NAME="Unknown"

    [[ -z "${BUILD_DESCRIPTION:-}" ]] \
        && BUILD_DESCRIPTION="No description provided"

    [[ -z "${BUILD_VENDOR:-}" ]] \
        && BUILD_VENDOR="Unknown"

    [[ -z "${BUILD_MAINTAINER:-}" ]] \
        && BUILD_MAINTAINER="Unknown"

    if [[ "${DOCKER_SQUASH}" = "true" && "${DOCKER_CACHE}" = "true" ]]; then
        display_notice_message \
            "Disabled Docker cache, since squashing is enabled."
        DOCKER_CACHE=false
    fi


    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Preparse the Dockerfile for build use
#
# Arguments:
#   None
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
prepare_dockerfile() {
    local -a labels

    display_status_message 'Preparing Dockerfile for use'

    # Ensure Dockerfile ends with a empty line
    DOCKERFILE+=$'\n'

    # Process labels
    if [[ "${BUILD_LABEL_OVERRIDE}" = true
        || ! "${EXISTING_LABELS[*]:-}" = *"org.label-schema.schema-version"*
    ]]; then
        labels+=("org.label-schema.schema-version=\"1.0\"")
    fi

    if [[ "${BUILD_LABEL_OVERRIDE}" = true
        || ! "${EXISTING_LABELS[*]:-}" = *"org.label-schema.build-date"*
    ]]; then
        if [[ ! "${EXISTING_ARGS[*]}" = *"BUILD_DATE"* ]]; then
            DOCKERFILE+="ARG BUILD_DATE"$'\n'
            EXISTING_ARGS+=(BUILD_DATE)
        fi
        labels+=("org.label-schema.build-date=\${BUILD_DATE}")
    fi

    if [[ "${BUILD_LABEL_OVERRIDE}" = true
        || ! "${EXISTING_LABELS[*]:-}" = *"org.label-schema.name"*
    ]]; then
        labels+=("org.label-schema.name=\"${BUILD_NAME}\"")
    fi

    if [[ "${BUILD_LABEL_OVERRIDE}" = true
        || ! "${EXISTING_LABELS[*]:-}" = *"org.label-schema.description"*
    ]]; then
        labels+=("org.label-schema.description=\"${BUILD_DESCRIPTION}\"")
    fi

    if [[ "${BUILD_LABEL_OVERRIDE}" = true
        || ! "${EXISTING_LABELS[*]:-}" = *"org.label-schema.url"*
    ]]; then
        labels+=("org.label-schema.url=\"${BUILD_URL}\"")
    fi

    if [[ "${BUILD_LABEL_OVERRIDE}" = true
        || ! "${EXISTING_LABELS[*]:-}" = *"org.label-schema.vcs-url"*
    ]]; then
        labels+=("org.label-schema.vcs-url=\"${BUILD_GIT_URL}\"")
    fi

    if [[ "${BUILD_LABEL_OVERRIDE}" = true
        || ! "${EXISTING_LABELS[*]:-}" = *"org.label-schema.vcs-ref"*
    ]]; then
        labels+=("org.label-schema.vcs-ref=\"${BUILD_REF}\"")
    fi

    if [[ "${BUILD_LABEL_OVERRIDE}" = true
        || ! "${EXISTING_LABELS[*]:-}" = *"org.label-schema.vendor"*
    ]]; then
        labels+=("org.label-schema.vendor=\"${BUILD_VENDOR}\"")
    fi

    if [[ "${BUILD_LABEL_OVERRIDE}" = true
        || ! "${EXISTING_LABELS[*]:-}" = *"org.label-schema.usage"*
    ]]; then
        labels+=("org.label-schema.usage=\"${BUILD_DOC_URL}\"")
    fi

    if [[ "${BUILD_LABEL_OVERRIDE}" = true
        || ! "${EXISTING_LABELS[*]:-}" = *"maintainer"*
    ]]; then
        labels+=("maintainer=\"${BUILD_MAINTAINER}\"")
    fi

    if [[ "${BUILD_LABEL_OVERRIDE}" = true
        || ! "${EXISTING_LABELS[*]:-}" = *"io.hass.type"*
    ]]; then
        labels+=("io.hass.type=${BUILD_TYPE}")
    fi

    if [[ "${BUILD_LABEL_OVERRIDE}" = true
        || ! "${EXISTING_LABELS[*]:-}" = *"org.label-schema.version"*
    ]]; then
        labels+=("org.label-schema.version=\"${BUILD_VERSION}\"")
    fi

    if [[
        "${BUILD_LABEL_OVERRIDE}" = true
        || ! "${EXISTING_LABELS[*]:-}" = *"io.hass.version"*
    ]]; then
        labels+=("io.hass.version=\"${BUILD_VERSION}\"")
    fi

    if [[ "${BUILD_LABEL_OVERRIDE}" = true
        || ! "${EXISTING_LABELS[*]:-}" = *"io.hass.arch"*
    ]]; then
        if [[ ! "${EXISTING_ARGS[*]}" = *"BUILD_ARCH"* ]]; then
            DOCKERFILE+="ARG BUILD_ARCH"$'\n'
            EXISTING_ARGS+=(BUILD_ARCH)
        fi
        labels+=("io.hass.arch=\${BUILD_ARCH}")
    fi

    if [[ ! -z "${labels[*]:-}" ]]; then
        IFS=" "
        DOCKERFILE+="LABEL ${labels[*]}"$'\n'
    fi

    return "${EX_OK}"
}

# ==============================================================================
# RUN LOGIC
# ------------------------------------------------------------------------------
main() {
    local -a background_jobs
    local exit_code=0

    trap 'cleanup_on_exit $?' EXIT SIGINT SIGTERM

    # Parse input
    display_banner
    parse_cli_arguments "$@"

    # Download source (if requested)
    [[ ! -z "${BUILD_REPOSITORY:-}" ]] && clone_repository

    # This might be an issue...
    [[ -f "${BUILD_TARGET}/Dockerfile" ]] \
        || display_error_message 'Dockerfile not found?' "${EX_DOCKERFILE}"

    # Gather build information
    [[ -f "${BUILD_TARGET}/config.json" ]] \
        && get_info_json "${BUILD_TARGET}/config.json"
    [[ -f "${BUILD_TARGET}/build.json" ]] \
        && get_info_json "${BUILD_TARGET}/build.json"
    get_info_git
    get_info_dockerfile

    # Getting ready
    preflight_checks
    prepare_defaults
    prepare_dockerfile

    # Docker daemon startup
    docker_enable_crosscompile
    docker_start_daemon

    # Cache warming
    display_status_message 'Warming up cache for all requested architectures'
    if [[ "${DOCKER_CACHE}" = true ]]; then
        for arch in "${BUILD_ARCHS[@]}"; do
            (docker_warmup_cache "${arch}" | sed -u "s/^/[${arch}] /") &
        done
    fi
    wait
    display_status_message 'Warmup for all requested architectures finished'

    # Building!
    display_status_message 'Starting build of all requested architectures'
    background_jobs=()
    if [[ "${BUILD_PARALLEL}" = true && ${#BUILD_ARCHS[@]} -ne 1 ]]; then
        for arch in "${BUILD_ARCHS[@]}"; do
            docker_build "${arch}" | sed -u "s/^/[${arch}] /" &
            background_jobs+=($!)
        done

        # Wait for all build jobs to finish
        for job in "${background_jobs[@]}"; do
            wait "${job}" || exit_code=$?
            if [[ "${exit_code}" -ne 0 ]]; then
                exit "${exit_code}"
            fi
        done
    else
        for arch in "${BUILD_ARCHS[@]}"; do
            docker_build "${arch}" | sed -u "s/^/[${arch}] /"
        done
    fi
    display_status_message 'Build of all requested architectures finished'

    # Tag it
    display_status_message 'Tagging Docker images'
    for arch in "${BUILD_ARCHS[@]}"; do
        docker_tag "${arch}" | sed "s/^/[${arch}] /"
    done
    wait

    # Push it
    if [[ "${DOCKER_PUSH}" = true ]]; then
        display_status_message 'Pushing all Docker images'
        background_jobs=()
        for arch in "${BUILD_ARCHS[@]}"; do
            docker_push "${arch}" | sed  -u "s/^/[${arch}] /" &
            background_jobs+=($!)
        done

        # Wait for all push jobs to finish
        for job in "${background_jobs[@]}"; do
            wait "${job}" || exit_code=$?
            if [[ "${exit_code}" -ne 0 ]]; then
                exit "${exit_code}"
            fi
        done
        display_status_message 'Pushing of all Docker images finished'
    fi

    # Fin
    exit "${EX_OK}"
}

# Bootstrap
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Direct call to file
    main "$@"
fi  # Else file is included from another script
