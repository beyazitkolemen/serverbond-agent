#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)"
LIB_SH="${SCRIPTS_DIR}/lib.sh"

if [[ ! -f "${LIB_SH}" ]]; then
    echo "lib.sh bulunamadı: ${LIB_SH}" >&2
    exit 1
fi

# shellcheck source=../lib.sh
source "${LIB_SH}"

require_root

MODE="default"
WEB_ROOT="${NGINX_DEFAULT_ROOT:-/var/www/html}"
SITES_AVAILABLE="${NGINX_SITES_AVAILABLE:-/etc/nginx/sites-available}"
TEMPLATES_DIR="${ROOT_DIR}/templates"

usage() {
    cat <<'USAGE'
Kullanım: nginx/rebuild_conf.sh [--mode default|laravel]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            MODE="${2:-default}"
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

case "${MODE}" in
    default)
        TEMPLATE_FILE="${TEMPLATES_DIR}/nginx-default.conf"
        HTML_TEMPLATE="${TEMPLATES_DIR}/nginx-default.html"
        ;;
    laravel)
        TEMPLATE_FILE="${TEMPLATES_DIR}/nginx-laravel.conf"
        HTML_TEMPLATE=""
        ;;
    *)
        log_error "Geçersiz mod: ${MODE}"
        exit 1
        ;;
esac

if [[ ! -f "${TEMPLATE_FILE}" ]]; then
    log_error "Template bulunamadı: ${TEMPLATE_FILE}"
    exit 1
fi

TARGET_FILE="${SITES_AVAILABLE}/default"
if [[ -f "${TARGET_FILE}" ]]; then
    cp "${TARGET_FILE}" "${TARGET_FILE}.bak.$(date +%s)"
fi

log_info "${TEMPLATE_FILE} -> ${TARGET_FILE} kopyalanıyor..."
cp "${TEMPLATE_FILE}" "${TARGET_FILE}"

if [[ -n "${HTML_TEMPLATE}" ]]; then
    mkdir -p "${WEB_ROOT}"
    cp "${HTML_TEMPLATE}" "${WEB_ROOT}/index.html"
fi

log_info "Nginx konfigürasyonu test ediliyor..."
if nginx -t; then
    systemctl_safe reload nginx
    log_success "Nginx konfigürasyonu yenilendi (${MODE})."
else
    log_error "Nginx testi başarısız oldu."
    exit 1
fi

