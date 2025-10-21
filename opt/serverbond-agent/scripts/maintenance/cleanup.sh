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

TARGET_DIR="${1:-$(pwd)}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            TARGET_DIR="${2:-}"
            shift 2
            ;;
        --help)
            cat <<'USAGE'
Kullanım: maintenance/cleanup.sh [--path /var/www/current]
USAGE
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

if [[ ! -d "${TARGET_DIR}" ]]; then
    log_error "Proje dizini bulunamadı: ${TARGET_DIR}"
    exit 1
fi

LOG_DIR="${TARGET_DIR}/storage/logs"
CACHE_DIR="${TARGET_DIR}/storage/framework/cache"
VIEW_DIR="${TARGET_DIR}/storage/framework/views"
SESSION_DIR="${TARGET_DIR}/storage/framework/sessions"

log_info "Laravel log dosyaları temizleniyor..."
find "${LOG_DIR}" -type f -name '*.log' -delete 2>/dev/null || true

log_info "Laravel cache klasörü temizleniyor..."
rm -rf "${CACHE_DIR}"/* 2>/dev/null || true
rm -rf "${VIEW_DIR}"/* 2>/dev/null || true
rm -rf "${SESSION_DIR}"/* 2>/dev/null || true

TMP_DIR="${TARGET_DIR}/storage/temp"
[[ -d "${TMP_DIR}" ]] && rm -rf "${TMP_DIR}"/* || true

log_success "Temizlik işlemi tamamlandı."

