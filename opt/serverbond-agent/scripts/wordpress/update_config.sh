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
DB_NAME=""
DB_USER=""
DB_PASSWORD=""
DB_HOST=""
TABLE_PREFIX=""
DEBUG_STATE=""
REGENERATE_SALTS="false"
APPLY_PERMISSIONS="false"
OWNER="$(wordpress_default_owner)"
GROUP="$(wordpress_default_group)"
declare -a CONFIG_SET_STRING=()
declare -a CONFIG_SET_RAW=()
declare -a CONFIG_REMOVE=()

usage() {
    cat <<'USAGE'
Kullanım: wordpress/update_config.sh --path /var/www/example \
    [--db-name db] [--db-user user] [--db-password pass] [--db-host localhost] \
    [--db-prefix wp_] [--set KEY=VALUE] [--set-raw KEY=EXPR] [--remove KEY] \
    [--enable-debug | --disable-debug] [--regenerate-salts] \
    [--apply-permissions] [--owner www-data] [--group www-data]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            WORDPRESS_PATH="${2:-}"
            shift 2
            ;;
        --db-name)
            DB_NAME="${2:-}"
            shift 2
            ;;
        --db-user)
            DB_USER="${2:-}"
            shift 2
            ;;
        --db-password)
            DB_PASSWORD="${2:-}"
            shift 2
            ;;
        --db-host)
            DB_HOST="${2:-}"
            shift 2
            ;;
        --db-prefix)
            TABLE_PREFIX="${2:-}"
            shift 2
            ;;
        --set)
            CONFIG_SET_STRING+=("${2:-}")
            shift 2
            ;;
        --set-raw)
            CONFIG_SET_RAW+=("${2:-}")
            shift 2
            ;;
        --remove)
            CONFIG_REMOVE+=("${2:-}")
            shift 2
            ;;
        --enable-debug)
            DEBUG_STATE="true"
            shift
            ;;
        --disable-debug)
            DEBUG_STATE="false"
            shift
            ;;
        --regenerate-salts)
            REGENERATE_SALTS="true"
            shift
            ;;
        --apply-permissions)
            APPLY_PERMISSIONS="true"
            shift
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

if ! check_command php; then
    log_error "PHP komutu bulunamadı."
    exit 1
fi

CONFIG_PATH="$(wordpress_config_path "${WORDPRESS_PATH}")"
log_info "wp-config.php güncelleniyor: ${CONFIG_PATH}"

if [[ -n "${DB_NAME}" ]]; then
    wordpress_config_set_constant "${CONFIG_PATH}" "DB_NAME" "${DB_NAME}"
fi
if [[ -n "${DB_USER}" ]]; then
    wordpress_config_set_constant "${CONFIG_PATH}" "DB_USER" "${DB_USER}"
fi
if [[ -n "${DB_PASSWORD}" ]]; then
    wordpress_config_set_constant "${CONFIG_PATH}" "DB_PASSWORD" "${DB_PASSWORD}"
fi
if [[ -n "${DB_HOST}" ]]; then
    wordpress_config_set_constant "${CONFIG_PATH}" "DB_HOST" "${DB_HOST}"
fi
if [[ -n "${TABLE_PREFIX}" ]]; then
    wordpress_config_set_table_prefix "${CONFIG_PATH}" "${TABLE_PREFIX}"
fi

if [[ -n "${DEBUG_STATE}" ]]; then
    wordpress_config_set_constant "${CONFIG_PATH}" "WP_DEBUG" "${DEBUG_STATE}" "raw"
fi

if [[ "${REGENERATE_SALTS}" == "true" ]]; then
    log_info "Salt anahtarları yeniden oluşturuluyor..."
    wordpress_config_set_salts "${CONFIG_PATH}"
fi

for item in "${CONFIG_SET_STRING[@]}"; do
    if [[ "${item}" != *=* ]]; then
        log_error "--set parametresi KEY=VALUE formatında olmalıdır: ${item}"
        exit 1
    fi
    key="${item%%=*}"
    value="${item#*=}"
    wordpress_config_set_constant "${CONFIG_PATH}" "${key}" "${value}"
    log_info "${key} değeri güncellendi."
done

for item in "${CONFIG_SET_RAW[@]}"; do
    if [[ "${item}" != *=* ]]; then
        log_error "--set-raw parametresi KEY=EXPR formatında olmalıdır: ${item}"
        exit 1
    fi
    key="${item%%=*}"
    value="${item#*=}"
    wordpress_config_set_constant "${CONFIG_PATH}" "${key}" "${value}" "raw"
    log_info "${key} değeri (raw) güncellendi."
done

for item in "${CONFIG_REMOVE[@]}"; do
    if [[ -z "${item}" ]]; then
        continue
    fi
    wordpress_config_remove_constant "${CONFIG_PATH}" "${item}"
    log_info "${item} girdisi kaldırıldı."
done

if [[ "${APPLY_PERMISSIONS}" == "true" ]]; then
    log_info "Dosya izinleri uygulanıyor (${OWNER}:${GROUP})..."
    wordpress_set_permissions "${WORDPRESS_PATH}" "${OWNER}" "${GROUP}"
fi

log_success "wp-config.php güncellemesi tamamlandı."
