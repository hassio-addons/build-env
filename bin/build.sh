#!/usr/bin/env bash
# ==============================================================================
#
# Community Hass.io Add-ons: Build environment builder
#
# Script for building our cross platform Docker build environment.
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
readonly EX_DOCKER_BUILD=3      # Docker build failed
readonly EX_DOCKER_PUSH=4       # Failed pushing Docker image
readonly EX_DOCKER_TAG=5        # Failed setting Docker tag
readonly EX_DOCKER=6            # Docker not found or running
readonly EX_GIT=7               # Is this a GIT repository?

# Constants
readonly BUILD_IMAGE="hassioaddons/build-env" # Docker image to create

# Global variables
declare BUILD_IMAGE
declare BUILD_REF
declare BUILD_VERSION
declare DOCKER_CACHE
declare DOCKER_PUSH
declare DOCKER_TAG_LATEST
declare DOCKER_TAG_TEST

# Default values
DOCKER_PUSH=false
DOCKER_TAG_LATEST=false
DOCKER_TAG_TEST=false
DOCKER_CACHE=true

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
    echo '----------------------------------------------------'
    echo 'Community Hass.io Add-ons: Build environment builder'
    echo '----------------------------------------------------'
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
Usage: ./bin/build.sh [options]

Options:

    -h, --help
        Display this help and exit.

    -l, --tag-latest
        Tag Docker build as latest.
        Note: This is automatically done when on latest GIT tag.

    -t. --tag-test
        Tag Docker build as test.
        Note: This is automatically GIT is clean.

    -n, --no-cache
        Disable build from cache.

    -p, --push
        Upload the resulting build to Docker hub.

EOF

    exit "${exit_code}"
}

# ==============================================================================
# SCRIPT LOGIC
# ==============================================================================

# ------------------------------------------------------------------------------
# Docker build the build environment
#
# Globals:
#   BUILD_IMAGE
#   BUILD_REF
#   BUILD_VERSION
#   DOCKER_CACHE
#   EX_DOCKER_BUILD
#   EX_OK
# Arguments:
#   None
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
docker_build() {
    local -a build_args
    local build_date

    display_status_message 'Running Docker build'

    build_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    build_args+=(--pull)
    build_args+=(--compress)
    build_args+=(--build-arg "BUILD_DATE=${build_date}")
    build_args+=(--build-arg "BUILD_REF=${BUILD_REF}")
    build_args+=(--build-arg "BUILD_VERSION=${BUILD_VERSION}")
    build_args+=(--tag "${BUILD_IMAGE}:${BUILD_VERSION}")

    if [[ "${DOCKER_CACHE}" = true ]]; then
        build_args+=(--cache-from "${BUILD_IMAGE}:latest")
    else
        build_args+=(--no-cache)
    fi

    echo "${build_args[@]}"
    docker build "${build_args[@]}" ./build-env \
        || display_error_message 'Docker build failed' "${EX_DOCKER_BUILD}"

    display_status_message 'Docker build finished'

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Push Docker build result to DockerHub
# Globals:
#   BUILD_IMAGE
#   BUILD_VERSION
#   DOCKER_TAG_LATEST
#   DOCKER_TAG_TEST
#   EX_DOCKER_PUSH
#   EX_OK
# Arguments:
#   None
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
docker_push() {
    display_status_message 'Pushing Docker image'
        docker push "${BUILD_IMAGE}:${BUILD_VERSION}" \
            || display_error_message 'Docker push failed' "${EX_DOCKER_PUSH}"
    display_status_message 'Push finished'

    if [[ "${DOCKER_TAG_LATEST}" = true ]]; then
        display_status_message 'Pushing Docker image tagged as latest'

        docker push "${BUILD_IMAGE}:latest" \
            || display_error_message 'Docker push failed' "${EX_DOCKER_PUSH}"

        display_status_message 'Push finished'
    fi

    if [[ "${DOCKER_TAG_TEST}" = true ]]; then
        display_status_message 'Pushing Docker image tagged as test'

        docker push "${BUILD_IMAGE}:test" \
            || display_error_message 'Docker push failed' "${EX_DOCKER_PUSH}"

        display_status_message 'Push finished'
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
#   None
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
docker_tag() {
    if [[ "${DOCKER_TAG_LATEST}" = true ]]; then
        display_status_message 'Tagging images as latest'
        docker tag "${BUILD_IMAGE}:${BUILD_VERSION}" "${BUILD_IMAGE}:latest" \
            || display_error_message 'Setting latest tag failed' \
                "${EX_DOCKER_TAG}"
    fi

    if [[ "${DOCKER_TAG_TEST}" = true ]]; then
        display_status_message 'Tagging images as test'
        docker tag "${BUILD_IMAGE}:${BUILD_VERSION}" "${BUILD_IMAGE}:test" \
            || display_error_message 'Setting test tag failed' \
                "${EX_DOCKER_TAG}"
    fi

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Try to pull latest version of the current image to use as cache
#
# Globals:
#   DOCKER_CACHE
#   DOCKER_IMAGE
#   EX_OK
# Arguments:
#   None
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
docker_warup_cache() {
    display_status_message 'Warming up cache'
    if ! docker pull "${BUILD_IMAGE}:latest" 2>&1; then
        display_notice_message 'Cache warup failed, continuing without it'
        DOCKER_CACHE=false
    fi

    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Check to see if the Docker daemon is actually running
#
# Globals:
#   EX_DOCKER
#   EX_OK
# Arguments:
#   None
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
require_docker_running() {
    display_status_message 'Ensuring Docker daemon is running'
    if ! docker info > /dev/null 2>&1; then
        display_error_message \
            'Cannot connect to the Docker daemon. Is it running?' \
            "${EX_DOCKER}"
    fi
    
    return "${EX_OK}"
}

# ------------------------------------------------------------------------------
# Tries to fetch information from the GIT repository
#
# Globals:
#   BUILD_REF
#   BUILD_VERSION
#   DOCKER_TAG_LATEST
#   DOCKER_TAG_TEST
#   EX_OK
# Arguments:
#   None
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
git_get_info() {
    local tag
    local ref

    display_status_message 'Collecting information from GIT'

    # Is the GIT repository dirty?
    if [[ -z "$(git status --porcelain)" ]]; then

        tag=$(git describe --exact-match HEAD --abbrev=0 --tags &> /dev/null \
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
# Ensure this directory / build environment is actually a GIT repository
#
# Globals:
#   EX_GIT
#   EX_OK
# Arguments:
#   None
# Returns:
#   Exit code
# ------------------------------------------------------------------------------
require_git_repository() {
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
# Globals:
#   DOCKER_CACHE
#   DOCKER_PUSH
#   DOCKER_TAG_LATEST
#   DOCKER_TAG_TEST
#   EX_UNKNOWN
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
            -l|--tag-latest)
                DOCKER_TAG_LATEST=true
                ;;
            -t|--tag-test)
                DOCKER_TAG_TEST=true
                ;;
            -n|--no-cache) 
                DOCKER_CACHE=false
                ;;
            -p|--push)
                DOCKER_PUSH=true
                ;;
            *)
                display_help "${EX_UNKNOWN}" "Argument '${1}' unknown."
                ;;
        esac
        shift
    done
}

# ==============================================================================
# RUN LOGIC
# ------------------------------------------------------------------------------
# Globals:
#   DOCKER_CACHE
#   DOCKER_PUSH
#   EX_OK
# Arguments:
#   None
# Returns:
#   None
# ------------------------------------------------------------------------------
main() {
    # Parse input
    display_banner
    parse_cli_arguments "$@"

    # Check requirements
    require_docker_running
    require_git_repository

    # Gather build information
    git_get_info

    # Cache warming
    [[ "${DOCKER_CACHE}" = true ]] && docker_warup_cache

    # Building!
    docker_build
    docker_tag

    [[ "${DOCKER_PUSH}" = true ]] && docker_push

    exit "${EX_OK}"
}

# Bootstrap
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Direct call to file
    main "$@"
fi  # Else file is included from another script
