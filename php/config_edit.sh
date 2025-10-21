#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMMON_SH="${ROOT_DIR}/scripts/common.sh"
PHP_COMMON="${SCRIPT_DIR}/_common.sh"

if [[ ! -f "${COMMON_SH}" || ! -f "${PHP_COMMON}" ]]; then
    echo "Gerekli ortak scriptler bulunamadı." >&2
    exit 1
fi

# shellcheck source=../scripts/common.sh
source "${COMMON_SH}"
# shellcheck source=php/_common.sh
source "${PHP_COMMON}"

require_root

ACTION=""
KEY=""
VALUE=""
SCOPE="fpm"

usage() {
    cat <<'USAGE'
Kullanım: php/config_edit.sh (--set key value | --get key | --edit) [--scope fpm|cli]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --set)
            ACTION="set"
            KEY="${2:-}"
            VALUE="${3:-}"
            shift 3
            ;;
        --get)
            ACTION="get"
            KEY="${2:-}"
            shift 2
            ;;
        --edit)
            ACTION="edit"
            shift
            ;;
        --scope)
            SCOPE="${2:-fpm}"
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

if [[ -z "${ACTION}" ]]; then
    usage
    exit 1
fi

PHP_BIN_PATH="$(php_bin)"
PHP_VERSION_SHORT="$("${PHP_BIN_PATH}" -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || true)"
if [[ -z "${PHP_VERSION_SHORT}" ]]; then
    log_error "PHP sürümü tespit edilemedi."
    exit 1
fi

case "${SCOPE}" in
    fpm)
        CONFIG_FILE="/etc/php/${PHP_VERSION_SHORT}/fpm/php.ini"
        SERVICE_NAME="$(php_detect_fpm_service)"
        ;;
    cli)
        CONFIG_FILE="/etc/php/${PHP_VERSION_SHORT}/cli/php.ini"
        SERVICE_NAME=""
        ;;
    *)
        log_error "Geçersiz scope: ${SCOPE}"
        exit 1
        ;;
esac

if [[ ! -f "${CONFIG_FILE}" ]]; then
    log_error "php.ini dosyası bulunamadı: ${CONFIG_FILE}"
    exit 1
fi

backup_config() {
    local backup="${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    cp "${CONFIG_FILE}" "${backup}"
    log_info "Yedek oluşturuldu: ${backup}"
}

case "${ACTION}" in
    get)
        if [[ -z "${KEY}" ]]; then
            log_error "Anahtar belirtilmelidir."
            exit 1
        fi
        grep -E "^${KEY}\s*=" "${CONFIG_FILE}" || {
            log_warning "${KEY} bulunamadı."
            exit 1
        }
        ;;
    set)
        if [[ -z "${KEY}" || -z "${VALUE}" ]]; then
            log_error "--set anahtar ve değer gerektirir."
            exit 1
        fi
        backup_config
        if grep -qE "^${KEY}\s*=" "${CONFIG_FILE}"; then
            sed -i "s|^${KEY}\s*=.*|${KEY} = ${VALUE}|" "${CONFIG_FILE}"
        else
            echo "${KEY} = ${VALUE}" >> "${CONFIG_FILE}"
        fi
        log_success "${KEY} = ${VALUE} olarak güncellendi."
        ;;
    edit)
        backup_config
        EDITOR_CMD="${EDITOR:-nano}"
        log_info "${CONFIG_FILE} dosyası ${EDITOR_CMD} ile açılıyor..."
        "${EDITOR_CMD}" "${CONFIG_FILE}"
        ;;
    *)
        usage
        exit 1
        ;;
esac

if [[ -n "${SERVICE_NAME}" ]]; then
    log_info "PHP-FPM yeniden başlatılıyor..."
    systemctl_safe restart "${SERVICE_NAME}" || log_warning "PHP-FPM yeniden başlatılamadı."
fi

