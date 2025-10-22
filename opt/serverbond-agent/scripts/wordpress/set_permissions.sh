#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)"
LIB_SH="${SCRIPTS_DIR}/lib.sh"
WORDPRESS_COMMON="${SCRIPT_DIR}/_common.sh"

if [[ ! -f "${LIB_SH}" || ! -f "${WORDPRESS_COMMON}" ]]; then
    echo "Gerekli ortak scriptler bulunamadı." >&2
    exit 1
fi

# shellcheck source=../lib.sh
source "${LIB_SH}"
# shellcheck source=wordpress/_common.sh
source "${WORDPRESS_COMMON}"

require_root

WORDPRESS_PATH=""
OWNER="$(wordpress_default_owner)"
GROUP="$(wordpress_default_group)"

usage() {
    cat <<'USAGE'
Kullanım: wordpress/set_permissions.sh --path /var/www/example [--owner www-data] [--group www-data]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            WORDPRESS_PATH="${2:-}"
            shift 2
            ;;
        --owner)
            OWNER="${2:-}"
            shift 2
            ;;
        --group)
            GROUP="${2:-}"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "Bilinmeyen seçenek: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "${WORDPRESS_PATH}" ]]; then
    log_error "--path parametresi zorunludur."
    exit 1
fi

if [[ ! -d "${WORDPRESS_PATH}" ]]; then
    log_error "Belirtilen dizin bulunamadı: ${WORDPRESS_PATH}"
    exit 1
fi

log_info "${WORDPRESS_PATH} için izinler uygulanıyor (${OWNER}:${GROUP})..."
wordpress_set_permissions "${WORDPRESS_PATH}" "${OWNER}" "${GROUP}"
log_success "İzinler güncellendi."
