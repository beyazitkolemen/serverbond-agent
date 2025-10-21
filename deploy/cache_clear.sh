#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMMON_SH="${ROOT_DIR}/scripts/common.sh"
DEPLOY_COMMON="${SCRIPT_DIR}/_common.sh"
PHP_COMMON="${ROOT_DIR}/php/_common.sh"

if [[ ! -f "${COMMON_SH}" || ! -f "${DEPLOY_COMMON}" || ! -f "${PHP_COMMON}" ]]; then
    echo "Gerekli ortak scriptler bulunamadı." >&2
    exit 1
fi

# shellcheck source=../scripts/common.sh
source "${COMMON_SH}"
# shellcheck source=deploy/_common.sh
source "${DEPLOY_COMMON}"
# shellcheck source=php/_common.sh
source "${PHP_COMMON}"

require_root

TARGET_DIR=""
COMMANDS=("cache:clear" "config:clear" "route:clear" "view:clear")

usage() {
    cat <<'USAGE'
Kullanım: deploy/cache_clear.sh [--path /var/www/current]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            TARGET_DIR="${2:-}"
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

if [[ -z "${TARGET_DIR}" ]]; then
    TARGET_DIR="$(current_release_dir)"
fi

if [[ -z "${TARGET_DIR}" || ! -d "${TARGET_DIR}" ]]; then
    log_error "Geçerli deploy dizini bulunamadı."
    exit 1
fi

if [[ ! -f "${TARGET_DIR}/artisan" ]]; then
    log_error "artisan dosyası bulunamadı: ${TARGET_DIR}/artisan"
    exit 1
fi

PHP_BIN_PATH="$(php_bin)"

(
    cd "${TARGET_DIR}"
    for cmd in "${COMMANDS[@]}"; do
        log_info "php artisan ${cmd} çalıştırılıyor..."
        "${PHP_BIN_PATH}" artisan "${cmd}" || log_warning "${cmd} komutu başarısız oldu."
    done
)

log_success "Laravel cache temizleme işlemleri tamamlandı."

