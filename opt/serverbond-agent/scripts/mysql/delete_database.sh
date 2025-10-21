#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)"
LIB_SH="${SCRIPTS_DIR}/lib.sh"
MYSQL_COMMON="${SCRIPT_DIR}/_common.sh"

if [[ ! -f "${LIB_SH}" || ! -f "${MYSQL_COMMON}" ]]; then
    echo "Gerekli ortak scriptler bulunamadı." >&2
    exit 1
fi

# shellcheck source=../lib.sh
source "${LIB_SH}"
# shellcheck source=mysql/_common.sh
source "${MYSQL_COMMON}"

require_root

DB_NAME=""
FORCE=false

usage() {
    cat <<'USAGE'
Kullanım: mysql/delete_database.sh --name veritabani [--force]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)
            DB_NAME="${2:-}"
            shift 2
            ;;
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

if [[ -z "${DB_NAME}" ]]; then
    log_error "Veritabanı adı (--name) zorunludur."
    exit 1
fi

if [[ "${FORCE}" != true ]]; then
    read -r -p "${DB_NAME} veritabanı silinecek. Emin misiniz? [y/N]: " answer
    if [[ "${answer}" != "y" && "${answer}" != "Y" ]]; then
        log_info "İşlem iptal edildi."
        exit 0
    fi
fi

log_warning "${DB_NAME} veritabanı siliniyor..."
mysql_exec "DROP DATABASE IF EXISTS \`${DB_NAME}\`;"
log_success "${DB_NAME} veritabanı silindi."

