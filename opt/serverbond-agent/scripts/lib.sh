#!/usr/bin/env bash
################################################################################
# Common Functions & Utilities
# Shared across all installation scripts
################################################################################
set -euo pipefail

# --- Colors ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# --- Logging ---
log_info()    { echo -e "${BLUE}[INFO]${NC} $*" >&1; }
log_success() { echo -e "${GREEN}[OK]${NC} $*" >&1; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $*" >&1; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# --- Common binaries ---
if command -v systemctl >/dev/null 2>&1; then
    readonly SYSTEMCTL_BIN="$(command -v systemctl)"
else
    readonly SYSTEMCTL_BIN="/bin/systemctl"
fi

# --- Systemd safe operations ---
systemctl_safe() {
    local action="${1:-}" service="${2:-}"

    if [[ -z "$action" || -z "$service" ]]; then
        log_warning "systemctl_safe: missing parameters"
        return 1
    fi

    if [[ "${SKIP_SYSTEMD:-false}" == "true" ]]; then
        log_warning "Skipping systemctl $action $service (no systemd mode)"
        return 0
    fi

    if ! command -v systemctl >/dev/null 2>&1; then
        log_warning "systemctl not found — skipping $action $service"
        return 0
    fi

    if ! systemctl "$action" "$service" >/dev/null 2>&1; then
        log_warning "Systemd command failed: systemctl $action $service"
        return 1
    fi
    return 0
}

# --- Check if service is running ---
check_service() {
    local service="${1:-}"
    if [[ -z "$service" ]]; then
        log_warning "check_service: missing service name"
        return 1
    fi
    [[ "${SKIP_SYSTEMD:-false}" == "true" ]] && return 0
    systemctl is-active --quiet "$service" 2>/dev/null
}

# --- Check if package is installed ---
check_package() {
    local package="${1:-}"
    if [[ -z "$package" ]]; then
        log_warning "check_package: missing package name"
        return 1
    fi

    if command -v dpkg >/dev/null 2>&1; then
        dpkg -l | awk '{print $2}' | grep -qx "$package"
    elif command -v rpm >/dev/null 2>&1; then
        rpm -q "$package" >/dev/null 2>&1
    else
        log_warning "Package manager not found"
        return 1
    fi
}

# --- Check if command exists ---
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# --- Require root privileges ---
require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        log_error "This script must be run with root privileges."
        exit 1
    fi
}

# --- Run command as specific user ---
run_as_user() {
    local user="${1:-}"
    shift || true

    if [[ -z "$user" ]]; then
        log_error "run_as_user: user not specified"
        return 1
    fi

    if [[ $# -eq 0 ]]; then
        log_error "run_as_user: command to execute not specified"
        return 1
    fi

    if [[ "$user" == "root" || "$user" == "0" ]]; then
        "$@"
        return $?
    fi

    if command -v runuser >/dev/null 2>&1; then
        runuser -u "$user" -- "$@"
    else
        sudo -H -u "$user" -- "$@"
    fi
}

# --- Create sudoers file for script directories ---
create_script_sudoers() {
    local name="${1:-}"
    shift || true

    if [[ -z "$name" ]]; then
        log_error "create_script_sudoers: name not specified"
        return 1
    fi

    if [[ $# -eq 0 ]]; then
        log_error "create_script_sudoers: at least one script directory must be specified"
        return 1
    fi

    local target_file="/etc/sudoers.d/serverbond-${name}"
    local -a entries=()
    local dir resolved_dir

    for dir in "$@"; do
        if [[ -z "$dir" || ! -d "$dir" ]]; then
            log_warning "create_script_sudoers: directory not found or invalid: $dir"
            continue
        fi

        resolved_dir="$(cd "$dir" && pwd)"
        entries+=("${resolved_dir%/}/*.sh")
    done

    if ((${#entries[@]} == 0)); then
        log_error "create_script_sudoers: no valid script directory found"
        return 1
    fi

    {
        echo "# ServerBond Panel - ${name} script permissions"
        echo "# This file was automatically created"
        echo ""
        local entry
        for entry in "${entries[@]}"; do
            echo "www-data ALL=(root) NOPASSWD:SETENV: ${entry}"
        done
    } >"${target_file}"

    chmod 440 "${target_file}"

    if ! visudo -c -f "${target_file}" >/dev/null 2>&1; then
        log_error "Sudoers validation failed: ${target_file}"
        rm -f "${target_file}"
        return 1
    fi

    log_success "Sudoers updated: ${target_file}"
    return 0
}

# --- Resolve first matching systemd unit ---
find_systemd_unit() {
    local pattern="${1:-}"
    if [[ -z "$pattern" ]]; then
        log_warning "find_systemd_unit: search pattern missing"
        return 1
    fi

    if ! command -v systemctl >/dev/null 2>&1; then
        return 1
    fi

    systemctl list-unit-files "$pattern" 2>/dev/null \
        | awk 'NR>1 && $1 != "" {print $1}' \
        | head -n 1
}
