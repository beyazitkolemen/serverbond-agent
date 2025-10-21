#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)"
LIB_SH="${SCRIPTS_DIR}/lib.sh"
MYSQL_COMMON="${SCRIPTS_DIR}/mysql/_common.sh"

if [[ ! -f "${LIB_SH}" || ! -f "${MYSQL_COMMON}" ]]; then
    echo "Gerekli ortak scriptler bulunamadı." >&2
    exit 1
fi

# shellcheck source=../lib.sh
source "${LIB_SH}"
# shellcheck source=mysql/_common.sh
source "${MYSQL_COMMON}"

require_root

DATABASE=""
INPUT_FILE=""

usage() {
    cat <<'USAGE'
Kullanım: maintenance/restore_db.sh --database veritabani --file yedek.sql.gz
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --database)
            DATABASE="${2:-}"
            shift 2
            ;;
        --file)
            INPUT_FILE="${2:-}"
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

if [[ -z "${DATABASE}" || -z "${INPUT_FILE}" ]]; then
    log_error "--database ve --file zorunludur."
    exit 1
fi

if [[ ! -f "${INPUT_FILE}" ]]; then
    log_error "Yedek dosyası bulunamadı: ${INPUT_FILE}"
    exit 1
fi

log_warning "${DATABASE} veritabanı geri yüklenecek."
if [[ "${INPUT_FILE}" == *.gz ]]; then
    gunzip -c "${INPUT_FILE}" | mysql -u"${MYSQL_ROOT_USER}" ${MYSQL_ROOT_PASSWORD:+-p"${MYSQL_ROOT_PASSWORD}"} "${DATABASE}"
else
    mysql -u"${MYSQL_ROOT_USER}" ${MYSQL_ROOT_PASSWORD:+-p"${MYSQL_ROOT_PASSWORD}"} "${DATABASE}" < "${INPUT_FILE}"
fi
log_success "Veritabanı geri yüklendi."

