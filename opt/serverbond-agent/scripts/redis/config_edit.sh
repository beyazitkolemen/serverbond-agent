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

CONFIG_FILE="${REDIS_CONFIG_FILE:-/etc/redis/redis.conf}"
ACTION=""
KEY=""
VALUE=""

usage() {
    cat <<'USAGE'
Kullanım: redis/config_edit.sh (--set <anahtar> <değer> | --get <anahtar> | --edit)
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

if [[ ! -f "${CONFIG_FILE}" ]]; then
    log_error "Redis konfigürasyon dosyası bulunamadı: ${CONFIG_FILE}"
    exit 1
fi

backup_config() {
    local backup="${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    cp "${CONFIG_FILE}" "${backup}"
    log_info "Yedek oluşturuldu: ${backup}"
}

SERVICE_NAME="${REDIS_SERVICE_NAME:-redis-server}"

case "${ACTION}" in
    get)
        if [[ -z "${KEY}" ]]; then
            log_error "Anahtar belirtilmedi."
            exit 1
        fi
        grep -E "^${KEY}(\s|$)" "${CONFIG_FILE}" || {
            log_warning "${KEY} anahtarı bulunamadı."
            exit 1
        }
        ;;
    set)
        if [[ -z "${KEY}" || -z "${VALUE}" ]]; then
            log_error "--set anahtar ve değer istemektedir."
            exit 1
        fi
        backup_config
        if grep -qE "^${KEY}(\s|$)" "${CONFIG_FILE}"; then
            sed -i "s|^${KEY}.*|${KEY} ${VALUE}|" "${CONFIG_FILE}"
        else
            echo "${KEY} ${VALUE}" >> "${CONFIG_FILE}"
        fi
        log_success "${KEY}=${VALUE} olarak güncellendi."
        systemctl_safe restart "${SERVICE_NAME}" || log_warning "Redis yeniden başlatılamadı."
        ;;
    edit)
        backup_config
        EDITOR_CMD="${EDITOR:-nano}"
        log_info "${CONFIG_FILE} dosyası ${EDITOR_CMD} ile açılıyor..."
        "${EDITOR_CMD}" "${CONFIG_FILE}"
        log_info "Değişiklikler uygulandıktan sonra Redis yeniden başlatılıyor..."
        systemctl_safe restart "${SERVICE_NAME}" || log_warning "Redis yeniden başlatılamadı."
        ;;
    *)
        usage
        exit 1
        ;;
esac

