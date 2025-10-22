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

FORMAT="table"
SHOW_SYSTEM=false

usage() {
    cat <<'USAGE'
Kullanım: mysql/list_databases.sh [--format table|list] [--show-system]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            FORMAT="${2:-table}"
            shift 2
            ;;
        --show-system)
            SHOW_SYSTEM=true
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

if [[ "${FORMAT}" == "table" ]]; then
    printf "%-30s %-15s %-20s %s\n" "VERİTABANI ADI" "KARAKTER SETİ" "COLLATION" "BOYUT (KB)"
    printf '%*s\n' 100 '' | tr ' ' '-'
    
    if [[ "${SHOW_SYSTEM}" == true ]]; then
        mysql_exec "SELECT 
            SCHEMA_NAME as 'Database',
            DEFAULT_CHARACTER_SET_NAME as 'Charset',
            DEFAULT_COLLATION_NAME as 'Collation',
            ROUND(SUM(data_length + index_length) / 1024, 2) as 'Size_KB'
            FROM information_schema.SCHEMATA s
            LEFT JOIN information_schema.TABLES t ON s.SCHEMA_NAME = t.TABLE_SCHEMA
            GROUP BY s.SCHEMA_NAME, s.DEFAULT_CHARACTER_SET_NAME, s.DEFAULT_COLLATION_NAME
            ORDER BY s.SCHEMA_NAME;" | while IFS=$'\t' read -r database charset collation size_kb; do
            if [[ "${database}" != "Database" ]]; then
                printf "%-30s %-15s %-20s %s\n" "${database}" "${charset}" "${collation}" "${size_kb:-0}"
            fi
        done
    else
        mysql_exec "SELECT 
            SCHEMA_NAME as 'Database',
            DEFAULT_CHARACTER_SET_NAME as 'Charset',
            DEFAULT_COLLATION_NAME as 'Collation',
            ROUND(SUM(data_length + index_length) / 1024, 2) as 'Size_KB'
            FROM information_schema.SCHEMATA s
            LEFT JOIN information_schema.TABLES t ON s.SCHEMA_NAME = t.TABLE_SCHEMA
            WHERE s.SCHEMA_NAME NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
            GROUP BY s.SCHEMA_NAME, s.DEFAULT_CHARACTER_SET_NAME, s.DEFAULT_COLLATION_NAME
            ORDER BY s.SCHEMA_NAME;" | while IFS=$'\t' read -r database charset collation size_kb; do
            if [[ "${database}" != "Database" ]]; then
                printf "%-30s %-15s %-20s %s\n" "${database}" "${charset}" "${collation}" "${size_kb:-0}"
            fi
        done
    fi
elif [[ "${FORMAT}" == "list" ]]; then
    if [[ "${SHOW_SYSTEM}" == true ]]; then
        mysql_exec "SHOW DATABASES;" | grep -v "Database"
    else
        mysql_exec "SHOW DATABASES;" | grep -v -E "(Database|information_schema|performance_schema|mysql|sys)"
    fi
else
    log_error "Geçersiz format: ${FORMAT}. table veya list kullanın."
    exit 1
fi
