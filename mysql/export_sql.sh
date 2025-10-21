#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMMON_SH="${ROOT_DIR}/scripts/common.sh"
MYSQL_COMMON="${SCRIPT_DIR}/_common.sh"

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
OUTPUT=""
GZIP=false

usage() {
    cat <<'USAGE'
Kullanım: mysql/export_sql.sh --database veritabani [--output /yol/dosya.sql] [--gzip]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --database)
            DATABASE="${2:-}"
            shift 2
            ;;
        --output)
            OUTPUT="${2:-}"
            shift 2
            ;;
        --gzip)
            GZIP=true
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

if [[ -z "${DATABASE}" ]]; then
    log_error "--database zorunludur."
    exit 1
fi

if [[ -z "${OUTPUT}" ]]; then
    TIMESTAMP="$(date +%Y%m%d%H%M%S)"
    OUTPUT="${DATABASE}_${TIMESTAMP}.sql"
fi

if ! check_command mysqldump; then
    log_error "mysqldump bulunamadı."
    exit 1
fi

CLIENT_OPTS=(-u"${MYSQL_ROOT_USER}" ${MYSQL_ROOT_PASSWORD:+-p"${MYSQL_ROOT_PASSWORD}"} "${DATABASE}")

log_info "${DATABASE} veritabanı dışa aktarılıyor..."
if [[ "${GZIP}" == true ]]; then
    mysqldump "${CLIENT_OPTS[@]}" | gzip > "${OUTPUT}.gz"
    log_success "Yedek oluşturuldu: ${OUTPUT}.gz"
else
    mysqldump "${CLIENT_OPTS[@]}" > "${OUTPUT}"
    log_success "Yedek oluşturuldu: ${OUTPUT}"
fi

