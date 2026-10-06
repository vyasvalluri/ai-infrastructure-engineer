#!/usr/bin/env bash

set -u

usage() {
    printf 'Usage: %s --confirm-daemon-host EXPECTED_DAEMON_HOST TRUSTED_LOCAL_IMAGE\n' "${0##*/}" >&2
    printf 'Image must already exist locally and provide /bin/sh and nvidia-smi.\n' >&2
}

fail() {
    local exit_code="$1"
    shift
    printf 'FAIL[%d]: %s\n' "$exit_code" "$*" >&2
    exit "$exit_code"
}

unsupported_docker_feature() {
    case "$1" in
        *"unknown flag: --pull"*|*"unknown flag: --read-only"*|*"unknown flag: --gpus"*|*"client version is too new"*|*"minimum supported API version"*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

if [[ "$(uname -s 2>/dev/null || printf unknown)" != "Linux" ]]; then
    fail 2 'Linux host required; GPU passthrough is not validated on macOS/Windows Docker Desktop.'
fi

if (( EUID == 0 )); then
    fail 2 'Run as an authorized unprivileged user; do not use sudo. Docker daemon access is host-root-equivalent.'
fi

if (( $# != 3 )) || [[ "$1" != "--confirm-daemon-host" || -z "$2" || -z "$3" || "$3" == -* ]]; then
    usage
    exit 2
fi

expected_daemon_host="$2"
image_reference="$3"
if [[ -n "${DOCKER_HOST:-}" || -n "${DOCKER_CONTEXT:-}" ]]; then
    fail 11 'DOCKER_HOST/DOCKER_CONTEXT overrides are not allowed; unset them and use a verified local Unix-socket context.'
fi

for utility in docker nvidia-smi; do
    command -v "$utility" >/dev/null 2>&1 || fail 10 "Required host utility not found: $utility"
done

context_name=$(docker context show 2>/dev/null) || fail 11 'Unable to determine Docker context.'
context_endpoint=$(docker context inspect "$context_name" \
    --format '{{ (index .Endpoints "docker").Host }}' 2>/dev/null) || \
    fail 11 'Unable to inspect the active Docker context endpoint.'

case "$context_endpoint" in
    unix://*) ;;
    *) fail 11 "Remote or non-local Docker endpoint rejected: $context_endpoint" ;;
esac

engine_os=$(docker info --format '{{.OSType}}' 2>/dev/null) || \
    fail 12 'Cannot reach the Docker daemon. Check its state and authorized socket access; do not use sudo.'
[[ "$engine_os" == "linux" ]] || fail 13 "Expected a Linux Docker engine; detected '$engine_os'."
engine_name=$(docker info --format '{{.Name}}' 2>/dev/null) || \
    fail 12 'Unable to determine Docker daemon host name.'
[[ "$engine_name" == "$expected_daemon_host" ]] || \
    fail 11 "Docker daemon reports host '$engine_name', not the explicitly confirmed host '$expected_daemon_host'."
local_host_name=$(uname -n 2>/dev/null) || fail 11 'Unable to determine the caller host name.'
[[ "$local_host_name" == "$expected_daemon_host" ]] || \
    fail 11 "Caller host '$local_host_name' does not match independently confirmed daemon host '$expected_daemon_host'."
engine_kernel=$(docker info --format '{{.KernelVersion}}' 2>/dev/null) || \
    fail 12 'Unable to determine Docker daemon kernel version.'
local_kernel=$(uname -r 2>/dev/null) || fail 11 'Unable to determine caller kernel version.'
[[ "$engine_kernel" == "$local_kernel" ]] || \
    fail 11 "Docker daemon kernel '$engine_kernel' differs from caller kernel '$local_kernel'; local host/daemon identity is not confirmed."
printf 'PASS: local Docker context %s; daemon host %s and kernel match caller (Linux).\n' "$context_name" "$engine_name"

image_id=$(docker image inspect "$image_reference" --format '{{.Id}}' 2>/dev/null) || \
    fail 14 'Image is not available locally. This script never pulls images; acquire and review it through an approved process first.'
[[ -n "$image_id" ]] || fail 14 'Docker returned an empty image ID.'

printf 'PASS: local Docker context (%s) and Linux engine are available.\n' "$context_name"
printf 'PASS: selected local image resolved to immutable ID %s.\n' "$image_id"
printf 'Trust requirement: use only an approved image; --gpus all exposes host GPU devices and is not a sandbox for untrusted code.\n'

host_gpu_output=$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>&1)
host_gpu_status=$?
if (( host_gpu_status != 0 )); then
    printf '%s\n' "$host_gpu_output" >&2
    fail 15 'Host nvidia-smi failed; host GPU/driver availability is not established.'
fi
[[ -n "$host_gpu_output" ]] || fail 15 'Host nvidia-smi returned no GPU rows.'
host_gpu_models=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null) || \
    fail 15 'Unable to query host GPU models.'
printf 'PASS: host driver and GPU inventory:\n%s\n' "$host_gpu_output"

shell_preflight=$(docker run --rm --pull=never --network none --read-only \
    --entrypoint /bin/sh "$image_id" \
    -c 'printf shell-ok' 2>&1)
shell_preflight_status=$?
if (( shell_preflight_status != 0 )); then
    printf '%s\n' "$shell_preflight" >&2
    if unsupported_docker_feature "$shell_preflight"; then
        fail 18 'Docker CLI/Engine does not support required probe flags or API level.'
    fi
    fail 16 'The trusted local image could not run /bin/sh; container GPU access was not tested.'
fi
printf 'PASS: image can run /bin/sh.\n'

utility_preflight=$(docker run --rm --pull=never --network none --read-only \
    --entrypoint /bin/sh "$image_id" \
    -c 'command -v nvidia-smi' 2>&1)
utility_preflight_status=$?
if (( utility_preflight_status != 0 )) || [[ -z "$utility_preflight" ]]; then
    printf '%s\n' "$utility_preflight" >&2
    if unsupported_docker_feature "$utility_preflight"; then
        fail 18 'Docker CLI/Engine does not support required probe flags or API level.'
    fi
    fail 16 'The image does not provide nvidia-smi; container GPU access was not tested.'
fi
printf 'PASS: image provides nvidia-smi at %s.\n' "$utility_preflight"

container_gpu_output=$(docker run --rm --pull=never --network none --read-only \
    --gpus all --entrypoint /bin/sh "$image_id" \
    -c 'nvidia-smi --query-gpu=name,driver_version --format=csv,noheader' 2>&1)
container_gpu_status=$?
if (( container_gpu_status != 0 )); then
    printf '%s\n' "$container_gpu_output" >&2
    if unsupported_docker_feature "$container_gpu_output"; then
        fail 18 'Docker CLI/Engine does not support required GPU flags or API level.'
    fi
    fail 17 'Container could not query a GPU. Investigate authorized NVIDIA Container Toolkit/runtime configuration and image compatibility; this script makes no changes.'
fi
[[ -n "$container_gpu_output" ]] || fail 17 'Container nvidia-smi returned no GPU rows.'
printf 'PASS: GPU is visible inside the disposable container:\n%s\n' "$container_gpu_output"
container_gpu_models=$(printf '%s\n' "$container_gpu_output" | \
    awk -F, '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1); print $1}')
host_models_sorted=$(printf '%s\n' "$host_gpu_models" | LC_ALL=C sort)
container_models_sorted=$(printf '%s\n' "$container_gpu_models" | LC_ALL=C sort)
if [[ "$host_models_sorted" == "$container_models_sorted" ]]; then
    printf 'PASS: host and container report matching GPU model inventories.\n'
else
    printf 'WARN: host and container GPU model inventories differ; review daemon host/device visibility.\n'
    printf 'Host models:\n%s\nContainer models:\n%s\n' "$host_gpu_models" "$container_gpu_models"
fi
printf 'PASS: both containers used --rm, --pull=never, --network none, --read-only, and no host mounts.\n'
printf 'Result: host GPU/driver available, GPU visible in container, model reported above.\n'
