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
readonly EX_GIT_CLONE=10        # Failed cloning GIT repository
readonly EX_GIT=12              # Is this a GIT repository?
readonly EX_INVALID_TYPE=12     # Invalid build type
readonly EX_MULTISTAGE=13       # Dockerfile contains multiple stages
readonly EX_NO_ARCHS=14         # No architectures to build
readonly EX_NO_IMAGE_NAME=15    # Missing name of image to build
readonly EX_NOT_EMPTY=16        # Workdirectory is not empty
readonly EX_PRIVILEGES=17       # Missing extended privileges
readonly EX_SUPPORTED=18        # Requested build architecture is not supported
readonly EX_VERSION=19          # Version not found and specified

# Constants
readonly DOCKER_PIDFILE='/var/run/docker.pid' # Docker daemon PID file
readonly DOCKER_TIMEOUT=20  # Wait 20 seconds for docker to start/exit

# Global variables
declare -a BUILD_ARCHS
declare -A BUILD_ARCHS_FROM
declare -A BUILD_ARGS
declare -a EXISTING_LABELS
declare -a SUPPORTED_ARCHS
declare -i DOCKER_PID
declare BUILD_ALL=false
declare BUILD_BRANCH
declare BUILD_FROM
declare BUILD_IMAGE
declare BUILD_PARALLEL
declare BUILD_REF
declare BUILD_REPOSITORY
declare BUILD_TARGET
declare BUILD_TYPE
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
BUILD_PARALLEL=true
BUILD_TARGET=$(pwd)
DOCKER_CACHE=true
DOCKER_PID=9999999999
DOCKER_PUSH=false
DOCKER_SQUASH=true
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
# Globals:
#   None
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
# Globals:
#   None
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
# Globals:
#   None
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
# Globals:
#   None
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
# Globals:
#   EX_OK
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
        Build for aarch64 architecture.

    --amd64
        Build for amd64 architecture.

    --armhf
        Build for armhf architecture.

    --i386
        Build for i386 architecture.

    -a, --all
        Build for all architectures.
        Same as --aarch64 --amd64 --armhf --i386.
        If a limited set of supported architectures are defined in
        a configuration file, that list is still honored when using
        this flag.

    ------ Build base images ------

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
        Defaults to "hassioaddons/base-{arch}"

    ------ Build output ------

    -i, --image <image>
        Specify a name for the output image.
        In case of building an add-on, this will override the name
        as set in the add-on configuration file. Use '{arch}' as an
        placeholder for the architecture name.
        e.g., --image "myname/{arch}-myaddon"

    -l, --tag-latest
        Tag Docker build as latest.
        Note: This is automatically done when on latest GIT tag AND
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

    -s, --single
        Do not parallelize builds. Build one architecture at the time.

    -q, --no-squash
        Do not squash the layers of the resulting image.

    ------ Build meta data ------

    -g, --git
        Use GIT for version tags instead of the add-on configuration file.
        Note: This will ONLY work when your GIT repository only contains
              a single add-on or other Docker container!

    --type <type>
        The type of the thing you are building.
        Valid values are: addon, base, cluster, homeassistant and supervisor.
        If you are unsure, then you probably don't need this flag.
        Defaults to 'addon'.

EOF

    exit "${exit_code}"
}

# ==============================================================================
# SCRIPT LOGIC
# ==============================================================================

# ------------------------------------------------------------------------------
# Cleanup function after execution is of the script is stopped. (trap)
#
# Globals:
#   EX_OK
#   TRAPPED
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
    fi

    exit "${exit_code}"
}

# ------------------------------------------------------------------------------
# Clones a remote GIT repository to a local working dir
#
# Globals:
#   BUILD_BRANCH
#   BUILD_REPOSITORY
#   EX_GIT_CLONE
#   EX_NOT_EMPTY
#   EX_OK
# Arguments:
#   None
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
clone_repository() {
    display_status_message 'Cloning remote GIT repository'

    [[ "$(ls -A ".")" ]] && display_error_message \
        '/docker mount is in used already, while requesting a repository' \
        "${EX_NOT_EMPTY}"

    git clone \
        --depth 1 --single-branch "${BUILD_REPOSITORY}" \
        -b "${BUILD_BRANCH}" "$(pwd)" \
        || display_error_message 'Failed cloning requested GIT repository' \
            "${EX_GIT_CLONE}"

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Start the Docker build
#
# Globals:
#   BUILD_ARCHS_FROM
#   BUILD_ARGS
#   BUILD_FROM
#   BUILD_IMAGE
#   BUILD_REF
#   BUILD_TARGET
#   BUILD_TYPE
#   BUILD_VERSION
#   DOCKER_CACHE
#   DOCKER_SQUASH
#   DOCKERFILE
#   EX_DOCKER_BUILD
#   EX_OK
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
    build_args+=(--compress)
    [[ "${DOCKER_SQUASH}" = true ]] && build_args+=(--squash)

    if [[ "${BUILD_ARCHS_FROM[${arch}]}" ]]; then
        build_args+=(--build-arg "BUILD_FROM=${BUILD_ARCHS_FROM[${arch}]}")
    else
        from="${BUILD_FROM//\{arch\}/${arch}}"
        build_args+=(--build-arg "BUILD_FROM=${from}")
    fi  

    build_args+=(--build-arg "BUILD_REF=${BUILD_REF}")
    build_args+=(--build-arg "BUILD_TYPE=${BUILD_TYPE}")
    build_args+=(--build-arg "BUILD_ARCH=${arch}")
    build_args+=(--build-arg "BUILD_DATE=${build_date}")

    for arg in "${!BUILD_ARGS[@]}"; do
        build_args+=(--build-arg "${arg}=${BUILD_ARGS[$arg]}")
    done
    
    build_args+=(--tag "${image}:${BUILD_VERSION}")

    if [[ "${DOCKER_CACHE}" = true ]]; then
        build_args+=(--cache-from "${BUILD_IMAGE}:latest")
    else
        build_args+=(--no-cache)
    fi

    IFS=' '
    echo "docker build ${build_args[*]}"

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
# Globals:
#   EX_CROSS
#   EX_OK
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
# Globals:
#   EX_CROSS
#   EX_OK
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
# Globals:
#   BUILD_IMAGE
#   BUILD_VERSION
#   DOCKER_TAG_LATEST
#   DOCKER_TAG_TEST
#   EX_DOCKER_PUSH
#   EX_OK
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
# Globals:
#   DOCKER_PID
#   DOCKER_TIMEOUT
#   EX_DOCKER_TIMEOUT
#   EX_OK
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
# Globals:
#   DOCKER_PID
#   DOCKER_TIMEOUT
#   EX_DOCKER_TIMEOUT
#   EX_OK
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
# Globals:
#   BUILD_IMAGE
#   BUILD_VERSION
#   DOCKER_TAG_LATEST
#   DOCKER_TAG_TEST
#   EX_DOCKER_TAG
#   EX_OK
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
# Globals:
#   BUILD_IMAGE
#   DOCKER_CACHE
#   EX_OK
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
# Globals:
#   BUILD_ARCHS_FROM
#   BUILD_ARGS
#   BUILD_FROM
#   BUILD_IMAGE
#   BUILD_TYPE
#   BUILD_VERSION
#   DOCKER_SQUASH
#   SUPPORTED_ARCHS
#   EX_OK
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
    
    squash=$(jq -r '.squash // empty' "${jsonfile}")
    [[ "${squash}" = "true" ]] && DOCKER_SQUASH=true
    [[ "${squash}" = "false" ]] && DOCKER_SQUASH=false

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
# Globals:
#   BUILD_TARGET
#   BUILD_TYPE
#   DOCKERFILE
#   EX_OK
#   EXISTING_LABELS
# Arguments:
#   None
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
get_info_dockerfile() {
    local from
    local labels
    local json

    display_status_message 'Collecting information from Dockerfile'

    DOCKERFILE=$(<"${BUILD_TARGET}/Dockerfile")
    json=$(dockerfile2json "${BUILD_TARGET}/Dockerfile")

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
                io.hass.type)
                    [[ -z "${BUILD_TYPE:-}" ]] && BUILD_TYPE="${value}"
                    ;;
            esac
        done <<< "${labels}"
    fi

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Tries to fetch information from the GIT repository
#
# Globals:
#   BUILD_GIT_URL
#   BUILD_REF
#   BUILD_URL
#   BUILD_VERSION
#   DOCKER_TAG_LATEST
#   DOCKER_TAG_TEST
#   EX_OK
# Arguments:
#   None
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
get_info_git() {
    local ref
    local tag

    display_status_message 'Collecting information from GIT'

    # Is the GIT repository dirty?
    if [[ -z "$(git status --porcelain)" ]]; then

        tag=$(git describe --exact-match HEAD --abbrev=0 --tags 2> /dev/null \
                || true)
        ref=$(git rev-parse --short HEAD)

        BUILD_REF="${ref}"

        # Is current HEAD on a tag?
        if [[ ! -z "${tag:-}" ]]; then
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
        # Uncomitted changes on the GIT repository, dirty!
        BUILD_REF="dirty"
        BUILD_VERSION="dirty"
        DOCKER_TAG_TEST=true
    fi

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Ensure this directory is actually a GIT repository
#
# Globals:
#   EX_GIT
#   EX_OK
# Arguments:
#   None
# Returns:
#   Exit cde
# ------------------------------------------------------------------------------
is_git_repository() {
    display_status_message 'Ensuring we are dealing with a GIT repository'
    if ! git -C . rev-parse; then
        display_error_message \
            'You have added --git, but is this a GIT repo?' \
            "${EX_GIT}"
    fi

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Parse CLI arguments
#
# Globals:
#   BUILD_ALL
#   BUILD_ARCHS
#   BUILD_ARCHS_FROM
#   BUILD_ARGS
#   BUILD_BRANCH
#   BUILD_FROM
#   BUILD_IMAGE
#   BUILD_PARALLEL
#   BUILD_REPOSITORY
#   BUILD_TARGET
#   BUILD_URL
#   DOCKER_CACHE
#   DOCKER_PUSH
#   DOCKER_SQUASH
#   DOCKER_TAG_LATEST
#   DOCKER_TAG_TEST
#   EX_UNKNOWN
#   USE_GIT
# Arguments:
#   None
# Returns:
#   None
# ------------------------------------------------------------------------------
parse_cli_arguments() {
    while [[ $# -gt 0 ]]; do
        case ${1} in
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
                BUILD_ARCHS_FROM['aarch64']=${2}
                shift
                ;;
            --amd64-from)
                BUILD_ARCHS_FROM['amd64']=${2}
                shift
                ;;
            --armhf-from)
                BUILD_ARCHS_FROM['armhf']=${2}
                shift
                ;;
            --i386-from)
                BUILD_ARCHS_FROM['i386']=${2}
                shift
                ;;
            -f|--from)
                BUILD_FROM=${2}
                shift
                ;;
            -i|--image)
                BUILD_IMAGE=${2}
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
            -q|--no-squash)
                DOCKER_SQUASH=false
                ;;
            -s|--single)
                BUILD_PARALLEL=false
                ;;
            -g|--git)
                USE_GIT=true
                ;;
            --type)
                BUILD_TYPE=${2}
                shift
                ;;
            -t|--target)
                BUILD_TARGET=${2}
                shift
                ;;
            -r|--repository)
                BUILD_REPOSITORY=${2}
                shift
                ;;
            -v|--version)
                BUILD_VERSION=${2}
                shift
                ;;
            -b|--branch)
                BUILD_BRANCH=${2}
                shift
                ;;
            --arg)
                BUILD_ARGS[${2}]=${3}
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
# Globals:
#   BUILD_ALL
#   BUILD_ARCHS
#   BUILD_IMAGE
#   BUILD_TYPE
#   BUILD_VERSION
#   EX_INVALID_TYPE
#   EX_MULTISTAGE
#   EX_NO_ARCHS
#   EX_OK
#   EX_PRIVILEGES
#   EX_SUPPORTED
#   EX_VERSION
#   SUPPORTED_ARCHS
# Arguments:
#   None
# Returns:
#   None
# ------------------------------------------------------------------------------
preflight_checks() {

    display_status_message 'Running preflight checks'

    # Deal breakers
    if ip link add dummy0 type dummy > /dev/null; then
        ip link delete dummy0 > /dev/null
    else
        display_error_message \
            'This build enviroment needs extended privileges (--privileged)' \
            "${EX_PRIVILEGES}"
    fi

    [[ ${#BUILD_ARCHS[@]} -eq 0 ]] && [[ "${BUILD_ALL}" = false ]] \
        && display_help "${EX_NO_ARCHS}" 'No architectures to build'

    [[ -z "${BUILD_VERSION:-}" ]] && display_error_message \
        'No version found and specified. Please use --version' "${EX_VERSION}"

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

    [[ $(awk '/^FROM/{a++}END{print a}' <<< "${DOCKERFILE}") -le 1 ]] || \
        display_error_message 'The Dockerfile seems to be multistage!' \
        "${EX_MULTISTAGE}"

    # Notices
    [[ -z "${BUILD_IMAGE:-}" ]] \
        && display_help "${EX_NO_IMAGE_NAME}" 'Missing build image name'

    [[ 
        "${BUILD_TYPE:-}" =~ ^(|addon|base|cluster|homeassistant|supervisor)$
    ]] || \
        display_help "$EX_INVALID_TYPE" "${BUILD_TYPE:-} is not a valid type."
    
    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Prepares all variables for building use
#
# Globals:
#   BUILD_ALL
#   BUILD_DOC_URL
#   BUILD_FROM
#   BUILD_GIT_URL
#   BUILD_REF
#   BUILD_TYPE
#   BUILD_URL
#   EX_OK
#   SUPPORTED_ARCHS
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

    [[ -z "${BUILD_REF:-}" ]] && BUILD_REF='Unknown'
    [[ -z "${BUILD_TYPE:-}" ]] && BUILD_TYPE='addon'
    [[ -z "${BUILD_FROM:-}" ]] && BUILD_FROM='hassioaddons/base-{arch}'

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Preparse the Dockerfile for build use
#
# This is mainly to maintain some form of backwards compatibility
#
# Globals:
#   DOCKERFILE
#   EX_OK
#   EXISTING_LABELS
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

    [[ ! "${EXISTING_LABELS[*]:-}" = *"io.hass.type"* ]] \
        && labels+=("io.hass.type=${BUILD_TYPE}")
    [[ ! "${EXISTING_LABELS[*]:-}" = *"io.hass.version"* ]] \
        && labels+=("io.hass.version=${BUILD_VERSION}")
    [[ ! "${EXISTING_LABELS[*]:-}" = *"io.hass.arch"* ]] \
        && labels+=("io.hass.arch=${BUILD_ARCH}")

    if [[ ! -z "${labels[*]:-}" ]]; then
        IFS=" "
        DOCKERFILE+="LABEL ${labels[*]}"$'\n'
    fi

    return "${EX_OK}"
}

# ==============================================================================
# RUN LOGIC
# ------------------------------------------------------------------------------
# Globals:
#   BUILD_ARCHS
#   BUILD_PARALLEL
#   BUILD_REPOSITORY
#   BUILD_TARGET
#   DOCKER_CACHE
#   DOCKER_PUSH
#   EX_DOCKERFILE
#   EX_OK
#   USE_GIT
# Arguments:
#   None
# Returns:
#   None
# ------------------------------------------------------------------------------
main() {
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

    if [[ "${USE_GIT}" = true ]]; then
        is_git_repository
        get_info_git
    fi
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
            (docker_warmup_cache "${arch}" | sed "s/^/[${arch}] /") &
        done
    fi
    wait
    display_status_message 'Warmup for all requested architectures finished'

    # Building!
    display_status_message 'Starting build of all requested architectures'
    if [[ "${BUILD_PARALLEL}" = true ]]; then
        for arch in "${BUILD_ARCHS[@]}"; do
            docker_build "${arch}" | sed "s/^/[${arch}] /" &
        done
        wait
    else
        for arch in "${BUILD_ARCHS[@]}"; do
            docker_build "${arch}" | sed "s/^/[${arch}] /"
        done
    fi  
    display_status_message 'Build of all requested architectures finished'

    # Tag it
    display_status_message 'Tagging Docker images'
    for arch in "${BUILD_ARCHS[@]}"; do
        docker_tag "${arch}" | sed "s/^/[${arch}] /" &
    done
    wait

    # Push it
    if [[ "${DOCKER_PUSH}" = true ]]; then
        display_status_message 'Pushing all Docker images'
        for arch in "${BUILD_ARCHS[@]}"; do
            docker_push "${arch}" | sed  "s/^/[${arch}] /" &
            done
        wait
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
