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

require_root

DOMAIN=""
PURGE_ROOT=false

SITES_AVAILABLE="${NGINX_SITES_AVAILABLE:-/etc/nginx/sites-available}"
SITES_ENABLED="${NGINX_SITES_ENABLED:-/etc/nginx/sites-enabled}"
DEFAULT_ROOT_BASE="${NGINX_DEFAULT_ROOT:-/var/www}"

usage() {
    cat <<'USAGE'
Kullanım: nginx/remove_site.sh --domain example.com [--purge-root]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain)
            DOMAIN="${2:-}"
            shift 2
            ;;
        --purge-root)
            PURGE_ROOT=true
            shift
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

if [[ -z "${DOMAIN}" ]]; then
    log_error "Alan adı (--domain) belirtilmelidir."
    exit 1
fi

CONFIG_FILE="${SITES_AVAILABLE}/${DOMAIN}.conf"
ENABLED_LINK="${SITES_ENABLED}/${DOMAIN}.conf"
WEB_ROOT="${DEFAULT_ROOT_BASE}/${DOMAIN}"

if [[ -L "${ENABLED_LINK}" || -f "${ENABLED_LINK}" ]]; then
    log_info "${ENABLED_LINK} kaldırılıyor..."
    rm -f "${ENABLED_LINK}"
fi

if [[ -f "${CONFIG_FILE}" ]]; then
    log_info "${CONFIG_FILE} siliniyor..."
    rm -f "${CONFIG_FILE}"
else
    log_warning "Konfigürasyon dosyası bulunamadı: ${CONFIG_FILE}"
fi

if [[ "${PURGE_ROOT}" == true && -d "${WEB_ROOT}" ]]; then
    log_warning "${WEB_ROOT} dizini kalıcı olarak silinecek."
    rm -rf "${WEB_ROOT}"
fi

if nginx -t; then
    systemctl_safe reload nginx
else
    log_warning "Nginx konfigürasyon testi başarısız oldu, reload atlandı."
fi

log_success "${DOMAIN} sitesi kaldırıldı."
