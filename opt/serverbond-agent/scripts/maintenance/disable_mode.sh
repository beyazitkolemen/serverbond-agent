#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)"
LIB_SH="${SCRIPTS_DIR}/lib.sh"
PHP_COMMON="${SCRIPTS_DIR}/php/_common.sh"

if [[ ! -f "${LIB_SH}" || ! -f "${PHP_COMMON}" ]]; then
    echo "Gerekli ortak scriptler bulunamadı." >&2
    exit 1
fi

# shellcheck source=../lib.sh
source "${LIB_SH}"
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

