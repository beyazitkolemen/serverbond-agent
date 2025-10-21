#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMMON_SH="${ROOT_DIR}/scripts/common.sh"
MYSQL_COMMON="${ROOT_DIR}/mysql/_common.sh"

if [[ ! -f "${COMMON_SH}" || ! -f "${MYSQL_COMMON}" ]]; then
    echo "Gerekli ortak scriptler bulunamadı." >&2
    exit 1
fi

# shellcheck source=../scripts/common.sh
source "${COMMON_SH}"
# shellcheck source=mysql/_common.sh
source "${MYSQL_COMMON}"

require_root

DATABASE=""
OUTPUT_FILE=""

usage() {
    cat <<'USAGE'
Kullanım: maintenance/backup_db.sh --database veritabani [--output /backups/db.sql.gz]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --database)
            DATABASE="${2:-}"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="${2:-}"
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

if [[ -z "${DATABASE}" ]]; then
    log_error "--database zorunludur."
    exit 1
fi

if ! check_command mysqldump; then
    log_error "mysqldump bulunamadı."
    exit 1
fi

if [[ -z "${OUTPUT_FILE}" ]]; then
    TIMESTAMP="$(date +%Y%m%d%H%M%S)"
    OUTPUT_FILE="${DATABASE}_${TIMESTAMP}.sql.gz"
fi

log_info "${DATABASE} veritabanı yedekleniyor..."
mysqldump -u"${MYSQL_ROOT_USER}" ${MYSQL_ROOT_PASSWORD:+-p"${MYSQL_ROOT_PASSWORD}"} "${DATABASE}" | gzip > "${OUTPUT_FILE}"
log_success "Veritabanı yedeği oluşturuldu: ${OUTPUT_FILE}"

