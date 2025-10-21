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

DB_NAME=""
CHARSET="utf8mb4"
COLLATION="utf8mb4_unicode_ci"

usage() {
    cat <<'USAGE'
Kullanım: mysql/create_database.sh --name veritabani [--charset utf8mb4] [--collation utf8mb4_unicode_ci]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)
            DB_NAME="${2:-}"
            shift 2
            ;;
        --charset)
            CHARSET="${2:-}"
            shift 2
            ;;
        --collation)
            COLLATION="${2:-}"
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

if [[ -z "${DB_NAME}" ]]; then
    log_error "Veritabanı adı (--name) zorunludur."
    exit 1
fi

SQL="SHOW DATABASES LIKE '${DB_NAME//"/\"}';"
if mysql_exec "${SQL}" | grep -q "${DB_NAME}"; then
    log_warning "${DB_NAME} veritabanı zaten mevcut."
    exit 0
fi

CREATE_SQL="CREATE DATABASE \`${DB_NAME}\` CHARACTER SET ${CHARSET} COLLATE ${COLLATION};"
log_info "${DB_NAME} veritabanı oluşturuluyor..."
mysql_exec "${CREATE_SQL}"
log_success "${DB_NAME} veritabanı oluşturuldu."

