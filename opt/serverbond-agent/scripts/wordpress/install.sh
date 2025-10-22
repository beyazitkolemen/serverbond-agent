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

INSTALL_PATH=""
SITE_URL=""
SITE_TITLE=""
ADMIN_USER=""
ADMIN_PASSWORD=""
ADMIN_EMAIL=""
DB_NAME=""
DB_USER=""
DB_PASSWORD=""
DB_HOST="localhost"
TABLE_PREFIX="wp_"
WORDPRESS_VERSION="latest"
WORDPRESS_LOCALE=""
SKIP_CORE_INSTALL="false"
SKIP_PERMISSIONS="false"
SKIP_SALTS="false"
FORCE_CLEAN="false"
OWNER="$(wordpress_default_owner)"
GROUP="$(wordpress_default_group)"

usage() {
    cat <<'USAGE'
Kullanım: wordpress/install.sh --path /var/www/example \
    --db-name db_adı --db-user db_kullanıcı --db-password db_şifre \
    [--url https://example.com] [--title "Site Başlığı"] \
    [--admin-user admin] [--admin-password şifre] [--admin-email admin@example.com] \
    [--db-host localhost] [--db-prefix wp_] [--version latest] [--locale tr_TR] \
    [--skip-core-install] [--skip-permissions] [--skip-salts] [--force] \
    [--owner www-data] [--group www-data]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            INSTALL_PATH="${2:-}"
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
        --url)
            SITE_URL="${2:-}"
            shift 2
            ;;
        --title)
            SITE_TITLE="${2:-}"
            shift 2
            ;;
        --admin-user)
            ADMIN_USER="${2:-}"
            shift 2
            ;;
        --admin-password)
            ADMIN_PASSWORD="${2:-}"
            shift 2
            ;;
        --admin-email)
            ADMIN_EMAIL="${2:-}"
            shift 2
            ;;
        --version)
            WORDPRESS_VERSION="${2:-}"
            shift 2
            ;;
        --locale)
            WORDPRESS_LOCALE="${2:-}"
            shift 2
            ;;
        --skip-core-install)
            SKIP_CORE_INSTALL="true"
            shift
            ;;
        --skip-permissions)
            SKIP_PERMISSIONS="true"
            shift
            ;;
        --skip-salts)
            SKIP_SALTS="true"
            shift
            ;;
        --force)
            FORCE_CLEAN="true"
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

if [[ -z "${INSTALL_PATH}" ]]; then
    log_error "--path parametresi zorunludur."
    exit 1
fi

if [[ "${INSTALL_PATH}" != "/" ]]; then
    INSTALL_PATH="${INSTALL_PATH%/}"
fi

if [[ -z "${DB_NAME}" || -z "${DB_USER}" || -z "${DB_PASSWORD}" ]]; then
    log_error "Veritabanı bilgileri (--db-name, --db-user, --db-password) zorunludur."
    exit 1
fi

if ! check_command php; then
    log_error "PHP komutu bulunamadı."
    exit 1
fi

if [[ -d "${INSTALL_PATH}" ]]; then
    if wordpress_is_dir_empty "${INSTALL_PATH}"; then
        log_info "Hedef dizin mevcut ancak boş: ${INSTALL_PATH}"
    else
        if [[ "${FORCE_CLEAN}" == "true" ]]; then
            if [[ "${INSTALL_PATH}" == "/" ]]; then
                log_error "Kök dizin temizlenemez."
                exit 1
            fi
            log_warning "Hedef dizin temizleniyor: ${INSTALL_PATH}"
            find "${INSTALL_PATH}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
        else
            log_error "Hedef dizin boş değil. --force kullanarak temizleyebilirsiniz."
            exit 1
        fi
    fi
else
    mkdir -p "${INSTALL_PATH}"
fi

DOWNLOAD_URL="https://wordpress.org/latest.tar.gz"
if [[ "${WORDPRESS_VERSION}" != "latest" ]]; then
    DOWNLOAD_URL="https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz"
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
ARCHIVE_PATH="${TMP_DIR}/wordpress.tar.gz"
EXTRACT_PATH="${TMP_DIR}/extracted"

log_info "WordPress paketi indiriliyor (${WORDPRESS_VERSION})..."
wordpress_download "${DOWNLOAD_URL}" "${ARCHIVE_PATH}"

log_info "Arşiv açılıyor..."
wordpress_extract "${ARCHIVE_PATH}" "${EXTRACT_PATH}"

if [[ ! -d "${EXTRACT_PATH}/wordpress" ]]; then
    log_error "WordPress arşivinden beklenen dizin bulunamadı."
    exit 1
fi

log_info "WordPress dosyaları ${INSTALL_PATH} dizinine kopyalanıyor..."
wordpress_copy_core "${EXTRACT_PATH}/wordpress" "${INSTALL_PATH}"

CONFIG_PATH="$(wordpress_config_path "${INSTALL_PATH}")"

log_info "Veritabanı bağlantı bilgileri yazılıyor..."
wordpress_config_set_constant "${CONFIG_PATH}" "DB_NAME" "${DB_NAME}"
wordpress_config_set_constant "${CONFIG_PATH}" "DB_USER" "${DB_USER}"
wordpress_config_set_constant "${CONFIG_PATH}" "DB_PASSWORD" "${DB_PASSWORD}"
wordpress_config_set_constant "${CONFIG_PATH}" "DB_HOST" "${DB_HOST}"
wordpress_config_set_table_prefix "${CONFIG_PATH}" "${TABLE_PREFIX}"

if [[ "${SKIP_SALTS}" == "false" ]]; then
    log_info "Gizli anahtarlar oluşturuluyor..."
    wordpress_config_set_salts "${CONFIG_PATH}"
fi

if [[ "${SKIP_PERMISSIONS}" == "false" ]]; then
    log_info "Dosya izinleri uygulanıyor (${OWNER}:${GROUP})..."
    wordpress_set_permissions "${INSTALL_PATH}" "${OWNER}" "${GROUP}"
fi

if [[ "${SKIP_CORE_INSTALL}" == "false" ]]; then
    if ! wordpress_wp_cli_bin >/dev/null 2>&1; then
        log_warning "WP-CLI bulunamadı, core install adımı atlandı."
    elif [[ -z "${SITE_URL}" || -z "${SITE_TITLE}" || -z "${ADMIN_USER}" || -z "${ADMIN_PASSWORD}" || -z "${ADMIN_EMAIL}" ]]; then
        log_warning "Core install için gerekli bilgiler eksik, atlandı."
    else
        local_wp_cli_user=""
        if id -u "${OWNER}" >/dev/null 2>&1; then
            local_wp_cli_user="${OWNER}"
        else
            log_warning "${OWNER} kullanıcısı bulunamadı, WP-CLI root ile çalıştırılacak."
        fi

        log_info "WP-CLI ile WordPress kurulumu tamamlanıyor..."
        declare -a wp_cmd=(
            "core" "install"
            "--url=${SITE_URL}"
            "--title=${SITE_TITLE}"
            "--admin_user=${ADMIN_USER}"
            "--admin_password=${ADMIN_PASSWORD}"
            "--admin_email=${ADMIN_EMAIL}"
            "--skip-email"
        )
        if [[ -n "${WORDPRESS_LOCALE}" ]]; then
            wp_cmd+=("--locale=${WORDPRESS_LOCALE}")
        fi

        if wordpress_run_wp_cli "${INSTALL_PATH}" "${local_wp_cli_user}" "${wp_cmd[@]}"; then
            log_success "WP-CLI core install tamamlandı."
        else
            log_warning "WP-CLI core install adımı başarısız oldu."
        fi
    fi
fi

log_success "WordPress kurulumu tamamlandı: ${INSTALL_PATH}"
