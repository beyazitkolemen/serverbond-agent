#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMMON_SH="${ROOT_DIR}/scripts/common.sh"

if [[ ! -f "${COMMON_SH}" ]]; then
    echo "common.sh bulunamadı: ${COMMON_SH}" >&2
    exit 1
fi

# shellcheck source=../scripts/common.sh
source "${COMMON_SH}"

usage() {
    cat <<'USAGE'
Kullanım: system/hostname.sh [--set <hostname>]
USAGE
}

if [[ $# -eq 0 ]]; then
    if command -v hostnamectl >/dev/null 2>&1; then
        hostnamectl status
    else
        hostname
    fi
    exit 0
fi

if [[ "${1:-}" == "--set" ]]; then
    NEW_HOSTNAME="${2:-}"
    if [[ -z "${NEW_HOSTNAME}" ]]; then
        log_error "Yeni hostname belirtilmedi."
        exit 1
    fi
    require_root
    if command -v hostnamectl >/dev/null 2>&1; then
        log_info "Hostname ${NEW_HOSTNAME} olarak ayarlanıyor..."
        hostnamectl set-hostname "${NEW_HOSTNAME}"
    else
        log_warning "hostnamectl bulunamadı, /etc/hostname dosyası güncellenecek."
        echo "${NEW_HOSTNAME}" > /etc/hostname
        hostname "${NEW_HOSTNAME}"
    fi
    log_success "Hostname güncellendi: ${NEW_HOSTNAME}"
else
    usage
    exit 1
fi
