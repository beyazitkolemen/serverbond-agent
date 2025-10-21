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

FILE=""
DATABASE=""
CHARSET="utf8mb4"

usage() {
    cat <<'USAGE'
Kullanım: mysql/import_sql.sh --file yedek.sql --database veritabani [--charset utf8mb4]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --file)
            FILE="${2:-}"
            shift 2
            ;;
        --database)
            DATABASE="${2:-}"
            shift 2
            ;;
        --charset)
            CHARSET="${2:-}"
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

if [[ -z "${FILE}" || -z "${DATABASE}" ]]; then
    log_error "--file ve --database zorunludur."
    exit 1
fi

if [[ "${FILE}" != "-" && ! -f "${FILE}" ]]; then
    log_error "SQL dosyası bulunamadı: ${FILE}"
    exit 1
fi

CLIENT="$(mysql_client)"
ARGS=(-u"${MYSQL_ROOT_USER}" ${MYSQL_ROOT_PASSWORD:+-p"${MYSQL_ROOT_PASSWORD}"} "${DATABASE}" --default-character-set="${CHARSET}")

log_info "${FILE} dosyası ${DATABASE} veritabanına aktarılıyor..."
if [[ "${FILE}" == "-" ]]; then
    "${CLIENT}" "${ARGS[@]}"
else
    "${CLIENT}" "${ARGS[@]}" < "${FILE}"
fi
log_success "SQL dosyası başarıyla içe aktarıldı."

