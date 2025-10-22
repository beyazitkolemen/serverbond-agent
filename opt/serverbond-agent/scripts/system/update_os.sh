#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)"
LIB_SH="${SCRIPTS_DIR}/lib.sh"

if [[ ! -f "${LIB_SH}" ]]; then
    echo "lib.sh not found: ${LIB_SH}" >&2
    exit 1
fi

# shellcheck source=../lib.sh
source "${LIB_SH}"

require_root

MODE="${1:-upgrade}"
export DEBIAN_FRONTEND=noninteractive

case "$MODE" in
    upgrade)
        log_info "Updating package lists..."
        apt-get update -qq
        log_info "Upgrading installed packages..."
        apt-get upgrade -y -qq
        ;;
    dist-upgrade)
        log_info "Updating package lists..."
        apt-get update -qq
        log_info "Applying distribution upgrade..."
        apt-get dist-upgrade -y -qq
        ;;
    security)
        log_info "Scanning for security updates only..."
        apt-get update -qq
        if check_command unattended-upgrade; then
            unattended-upgrade -d
        else
            log_warning "unattended-upgrade not found, applying standard upgrade."
            apt-get upgrade -y -qq
        fi
        ;;
    *)
        log_error "Unknown mode: ${MODE}"
        echo "Usage: system/update_os.sh [upgrade|dist-upgrade|security]" >&2
        exit 1
        ;;
esac

log_info "Cleaning up unnecessary packages..."
apt-get autoremove -y -qq
apt-get autoclean -y -qq

log_success "System update completed."
