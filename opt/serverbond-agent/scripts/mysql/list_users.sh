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
SHOW_PASSWORDS=false

usage() {
    cat <<'USAGE'
Kullanım: mysql/list_users.sh [--format table|list] [--show-passwords]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            FORMAT="${2:-table}"
            shift 2
            ;;
        --show-passwords)
            SHOW_PASSWORDS=true
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
    if [[ "${SHOW_PASSWORDS}" == true ]]; then
        printf "%-20s %-20s %-15s %-20s %s\n" "KULLANICI" "HOST" "AUTH PLUGIN" "SON GİRİŞ" "YETKİLER"
        printf '%*s\n' 100 '' | tr ' ' '-'
        
        mysql_exec "SELECT user, host, plugin, last_login, 
                   GROUP_CONCAT(DISTINCT CONCAT(privilege_type, ' ON ', table_schema, '.', table_name) SEPARATOR ', ') as privileges
                   FROM mysql.user u
                   LEFT JOIN information_schema.user_privileges p ON u.user = p.grantee
                   GROUP BY u.user, u.host, u.plugin, u.last_login
                   ORDER BY u.user, u.host;" | while IFS=$'\t' read -r user host plugin last_login privileges; do
            if [[ "${user}" != "user" ]]; then
                printf "%-20s %-20s %-15s %-20s %s\n" "${user}" "${host}" "${plugin}" "${last_login:-N/A}" "${privileges:-N/A}"
            fi
        done
    else
        printf "%-20s %-20s %-15s %-20s %s\n" "KULLANICI" "HOST" "AUTH PLUGIN" "SON GİRİŞ" "YETKİLER"
        printf '%*s\n' 100 '' | tr ' ' '-'
        
        mysql_exec "SELECT user, host, plugin, last_login, 
                   GROUP_CONCAT(DISTINCT CONCAT(privilege_type, ' ON ', table_schema, '.', table_name) SEPARATOR ', ') as privileges
                   FROM mysql.user u
                   LEFT JOIN information_schema.user_privileges p ON u.user = p.grantee
                   GROUP BY u.user, u.host, u.plugin, u.last_login
                   ORDER BY u.user, u.host;" | while IFS=$'\t' read -r user host plugin last_login privileges; do
            if [[ "${user}" != "user" ]]; then
                printf "%-20s %-20s %-15s %-20s %s\n" "${user}" "${host}" "${plugin}" "${last_login:-N/A}" "${privileges:-N/A}"
            fi
        done
    fi
elif [[ "${FORMAT}" == "list" ]]; then
    mysql_exec "SELECT CONCAT(user, '@', host) as user_host FROM mysql.user ORDER BY user, host;" | grep -v "user_host"
else
    log_error "Geçersiz format: ${FORMAT}. table veya list kullanın."
    exit 1
fi
