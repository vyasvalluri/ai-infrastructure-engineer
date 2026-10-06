#!/usr/bin/env bash

set -u

kernel_name=$(uname -s 2>/dev/null || printf 'unknown')
if [[ "$kernel_name" != "Linux" ]]; then
    printf 'ERROR: linux-diagnostics.sh supports Linux only; detected %s.\n' "$kernel_name"
    exit 2
fi
if (( EUID == 0 )); then
    printf 'ERROR: run linux-diagnostics.sh as an unprivileged user; do not use sudo.\n'
    exit 2
fi

printf 'Acme AI Cloud - Linux Host Diagnostic Report\n'
printf 'Collected UTC: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || printf 'unavailable')"
printf 'Kernel: %s\n' "$(uname -r 2>/dev/null || printf 'unavailable')"
printf 'Scope: read-only probes visible to the current user; no privilege escalation.\n'
printf 'Privacy: report may expose hostnames, addresses, mount paths, usernames, and process names.\n'

section() {
    printf '\n== %s ==\n' "$1"
}

probe() {
    local label="$1"
    shift
    section "$label"

    if ! command -v "$1" >/dev/null 2>&1; then
        printf '[SKIPPED] optional utility not installed: %s\n' "$1"
        return 0
    fi

    "$@" 2>&1
    local command_status=$?
    if (( command_status != 0 )); then
        printf '[WARN] command exited with status %d; inspect its message for access denial or unsupported options.\n' "$command_status"
    fi
}

limited_probe() {
    local label="$1"
    local line_limit="$2"
    shift 2
    section "$label (first ${line_limit} lines)"

    if ! command -v "$1" >/dev/null 2>&1; then
        printf '[SKIPPED] optional utility not installed: %s\n' "$1"
        return 0
    fi
    if ! command -v sed >/dev/null 2>&1; then
        printf '[SKIPPED] sed is unavailable; bounded output cannot be produced safely.\n'
        return 0
    fi

    "$@" 2>&1 | sed -n "1,${line_limit}p"
    local command_status=${PIPESTATUS[0]}
    if (( command_status != 0 )); then
        printf '[WARN] command exited with status %d; inspect its message for access denial or unsupported options.\n' "$command_status"
    fi
}

show_file() {
    local path="$1"
    local line_limit="$2"

    if [[ ! -e "$path" ]]; then
        printf '\n[SKIPPED] not present or unsupported: %s\n' "$path"
    elif [[ -r "$path" ]]; then
        printf '\n-- %s (first %s lines) --\n' "$path" "$line_limit"
        sed -n "1,${line_limit}p" "$path" 2>&1 || printf '[WARN] unable to read %s\n' "$path"
    else
        printf '\n[SKIPPED] permission denied or not readable: %s\n' "$path"
    fi
}

probe 'CPU topology' lscpu
probe 'Memory summary' free -h
show_file /proc/meminfo 16

section 'Pressure stall information (kernel/configuration dependent)'
show_file /proc/pressure/cpu 4
show_file /proc/pressure/memory 4
show_file /proc/pressure/io 4

section 'Visible cgroup v2 limits (mount/namespace scope may differ)'
show_file /sys/fs/cgroup/cpu.max 2
show_file /sys/fs/cgroup/cpu.stat 12
show_file /sys/fs/cgroup/memory.max 2
show_file /sys/fs/cgroup/memory.current 2
show_file /sys/fs/cgroup/memory.events 12

section 'Filesystem capacity and types (10-second timeout)'
if command -v timeout >/dev/null 2>&1; then
    timeout 10s df -hT 2>&1
    command_status=$?
    if (( command_status == 124 )); then
        printf '[WARN] df timed out; a filesystem, possibly remote, may be unresponsive.\n'
    elif (( command_status != 0 )); then
        printf '[WARN] df exited with status %d.\n' "$command_status"
    fi
else
    printf '[SKIPPED] timeout utility is unavailable; df was not run because a stale remote mount could block.\n'
fi
probe 'Block devices and mount points' lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINT
probe 'Block I/O statistics (one since-boot report plus three one-second samples; optional sysstat package)' iostat -xz 1 4

probe 'Network addresses' ip -brief address
probe 'Kernel routes' ip route show
probe 'Socket summary' ss -s
probe 'Listening TCP sockets (addresses and ports may be sensitive)' ss -lnt

limited_probe 'CPU-heavy processes (arguments and environment values omitted)' 16 \
    ps -eo pid,ppid,user,stat,pcpu,pmem,comm --sort=-pcpu

probe 'Kernel and architecture' uname -a
limited_probe 'Loaded kernel modules' 32 lsmod
limited_probe 'PCIe device inventory (numeric vendor/device IDs)' 48 lspci -nn

if command -v journalctl >/dev/null 2>&1; then
    limited_probe 'Kernel messages from current boot (permission-dependent)' 40 \
        journalctl -k -b --no-pager -n 40
else
    section 'Kernel messages'
    printf '[SKIPPED] journalctl is unavailable; this host may not use systemd-journald.\n'
fi

if command -v systemctl >/dev/null 2>&1; then
    limited_probe 'Failed systemd units' 32 systemctl --failed --no-pager
    limited_probe 'Running systemd services' 32 \
        systemctl list-units --type=service --state=running --no-pager --no-legend
else
    section 'Services'
    printf '[SKIPPED] systemctl is unavailable; this host may not use systemd or may be a container.\n'
fi

printf '\nReport complete. Missing tools, unreadable files, and unsupported facilities are reported as skipped or warned; they do not stop collection.\n'
