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

EXTENSION=""

usage() {
    cat <<'USAGE'
Kullanım: php/install_extension.sh --extension redis
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --extension)
            EXTENSION="${2:-}"
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

if [[ -z "${EXTENSION}" ]]; then
    log_error "--extension zorunludur."
    exit 1
fi

PHP_BIN_PATH="$(php_bin)"
PHP_VERSION_SHORT="$("${PHP_BIN_PATH}" -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || true)"
if [[ -z "${PHP_VERSION_SHORT}" ]]; then
    log_error "PHP sürümü tespit edilemedi."
    exit 1
fi

PACKAGE="php${PHP_VERSION_SHORT}-${EXTENSION}"
log_info "${PACKAGE} paketi kuruluyor..."
apt-get update -qq
if apt-get install -y "${PACKAGE}"; then
    log_success "${PACKAGE} paketi kuruldu."
else
    log_error "${PACKAGE} kurulamadı."
    exit 1
fi

if check_command phpenmod; then
    log_info "phpenmod ${EXTENSION} çalıştırılıyor..."
    phpenmod "${EXTENSION}" || log_warning "phpenmod başarısız olabilir."
fi

SERVICE_NAME="$(php_detect_fpm_service)"
log_info "PHP-FPM yeniden başlatılıyor..."
systemctl_safe restart "${SERVICE_NAME}" || log_warning "PHP-FPM yeniden başlatılamadı."

