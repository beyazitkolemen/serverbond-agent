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

FORCE=false

usage() {
    cat <<'USAGE'
Kullanım: redis/flush_all.sh [--force]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            FORCE=true
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

if ! check_command redis-cli; then
    log_error "redis-cli bulunamadı."
    exit 1
fi

if [[ "${FORCE}" != true ]]; then
    read -r -p "Tüm Redis veritabanları silinecek. Emin misiniz? [y/N]: " answer
    if [[ "${answer}" != "y" && "${answer}" != "Y" ]]; then
        log_info "İşlem iptal edildi."
        exit 0
    fi
fi

log_warning "Redis FLUSHALL komutu gönderiliyor..."
redis-cli FLUSHALL
log_success "Tüm Redis veritabanları temizlendi."

