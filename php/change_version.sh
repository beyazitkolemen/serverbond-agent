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

VERSION=""
CLI_ONLY=false

usage() {
    cat <<'USAGE'
Kullanım: php/change_version.sh --version 8.2 [--cli-only]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            VERSION="${2:-}"
            shift 2
            ;;
        --cli-only)
            CLI_ONLY=true
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

if [[ -z "${VERSION}" ]]; then
    log_error "--version zorunludur."
    exit 1
fi

PHP_BIN_TARGET="/usr/bin/php${VERSION}"
if [[ ! -x "${PHP_BIN_TARGET}" ]]; then
    log_error "${PHP_BIN_TARGET} bulunamadı. Önce php${VERSION} paketini kurun."
    exit 1
fi

if check_command update-alternatives; then
    log_info "update-alternatives ile PHP CLI sürümü güncelleniyor..."
    update-alternatives --set php "${PHP_BIN_TARGET}" || log_warning "update-alternatives başarısız oldu."
    if [[ -x "/usr/bin/php-config${VERSION}" ]]; then
        update-alternatives --set php-config "/usr/bin/php-config${VERSION}" || true
    fi
    if [[ -x "/usr/bin/phpize${VERSION}" ]]; then
        update-alternatives --set phpize "/usr/bin/phpize${VERSION}" || true
    fi
else
    log_warning "update-alternatives bulunamadı. CLI sürümü manuel güncellenmelidir."
fi

if [[ "${CLI_ONLY}" == true ]]; then
    log_success "PHP CLI sürümü ${VERSION} olarak ayarlandı."
    exit 0
fi

CURRENT_SERVICE="$(php_detect_fpm_service)"
NEW_SERVICE="php${VERSION}-fpm"

if [[ "${CURRENT_SERVICE}" == "${NEW_SERVICE}" ]]; then
    log_info "PHP-FPM zaten ${VERSION} sürümünde."
else
    log_info "${CURRENT_SERVICE} servisi durduruluyor..."
    systemctl_safe stop "${CURRENT_SERVICE}" || true
fi

log_info "${NEW_SERVICE} servisi başlatılıyor..."
if systemctl list-unit-files "${NEW_SERVICE}.service" >/dev/null 2>&1; then
    systemctl_safe enable "${NEW_SERVICE}" || true
    systemctl_safe start "${NEW_SERVICE}" || {
        log_error "${NEW_SERVICE} başlatılamadı."
        exit 1
    }
    log_success "PHP-FPM ${VERSION} sürümüne geçirildi."
else
    log_error "${NEW_SERVICE} servisi bulunamadı."
    exit 1
fi

