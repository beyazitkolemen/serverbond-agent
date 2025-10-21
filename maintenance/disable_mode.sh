#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMMON_SH="${ROOT_DIR}/scripts/common.sh"
PHP_COMMON="${ROOT_DIR}/php/_common.sh"

if [[ ! -f "${COMMON_SH}" || ! -f "${PHP_COMMON}" ]]; then
    echo "Gerekli ortak scriptler bulunamadı." >&2
    exit 1
fi

# shellcheck source=../scripts/common.sh
source "${COMMON_SH}"
# shellcheck source=php/_common.sh
source "${PHP_COMMON}"

require_root

TARGET_DIR="${1:-$(pwd)}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            TARGET_DIR="${2:-}"
            shift 2
            ;;
        --help)
            cat <<'USAGE'
Kullanım: maintenance/disable_mode.sh [--path /var/www/current]
USAGE
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

if [[ ! -f "${TARGET_DIR}/artisan" ]]; then
    log_error "artisan dosyası bulunamadı: ${TARGET_DIR}"
    exit 1
fi

PHP_BIN_PATH="$(php_bin)"
(
    cd "${TARGET_DIR}"
    "${PHP_BIN_PATH}" artisan up
)
log_success "Uygulama bakım modundan çıkarıldı."

