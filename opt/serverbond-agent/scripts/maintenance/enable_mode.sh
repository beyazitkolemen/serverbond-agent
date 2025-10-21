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
REASON=""
DURATION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            TARGET_DIR="${2:-}"
            shift 2
            ;;
        --message)
            REASON="${2:-}"
            shift 2
            ;;
        --retry)
            DURATION="${2:-}"
            shift 2
            ;;
        --help)
            cat <<'USAGE'
Kullanım: maintenance/enable_mode.sh [--path /var/www/current] [--message "Bakım"] [--retry 60]
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
ARGS=(down)
[[ -n "${REASON}" ]] && ARGS+=(--message "${REASON}")
[[ -n "${DURATION}" ]] && ARGS+=(--retry "${DURATION}")

(
    cd "${TARGET_DIR}"
    "${PHP_BIN_PATH}" artisan "${ARGS[@]}"
)
log_success "Uygulama bakım moduna alındı."

