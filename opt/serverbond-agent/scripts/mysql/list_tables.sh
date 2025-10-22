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

DATABASE=""
FORMAT="table"

usage() {
    cat <<'USAGE'
Kullanım: mysql/list_tables.sh --database veritabani [--format table|list]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --database)
            DATABASE="${2:-}"
            shift 2
            ;;
        --format)
            FORMAT="${2:-table}"
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

if [[ "${FORMAT}" == "table" ]]; then
    printf "%-30s %-20s %-15s %s\n" "TABLO ADI" "SATIR SAYISI" "BOYUT (KB)" "AÇIKLAMA"
    printf '%*s\n' 100 '' | tr ' ' '-'
    
    mysql_exec "USE \`${DATABASE}\`; SHOW TABLE STATUS;" | while IFS=$'\t' read -r name engine version row_format rows avg_row_length data_length max_data_length index_length data_free auto_increment create_time update_time check_time collation checksum create_options comment; do
        if [[ "${name}" != "Name" ]]; then
            size_kb=$((data_length / 1024))
            printf "%-30s %-20s %-15s %s\n" "${name}" "${rows}" "${size_kb}" "${comment:-}"
        fi
    done
elif [[ "${FORMAT}" == "list" ]]; then
    mysql_exec "USE \`${DATABASE}\`; SHOW TABLES;" | grep -v "Tables_in_"
else
    log_error "Geçersiz format: ${FORMAT}. table veya list kullanın."
    exit 1
fi
