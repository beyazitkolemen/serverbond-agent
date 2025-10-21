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

SITES_AVAILABLE="${NGINX_SITES_AVAILABLE:-/etc/nginx/sites-available}"
SITES_ENABLED="${NGINX_SITES_ENABLED:-/etc/nginx/sites-enabled}"

printf "%-30s %-50s %s\n" "ALAN ADI" "KONFİG" "ETKİN"
printf '%*s\n' 110 '' | tr ' ' '-'

shopt -s nullglob
for conf in "${SITES_AVAILABLE}"/*.conf; do
    domain="$(basename "${conf}" .conf)"
    if [[ -L "${SITES_ENABLED}/${domain}.conf" || -f "${SITES_ENABLED}/${domain}.conf" ]]; then
        enabled="evet"
    else
        enabled="hayır"
    fi
    printf "%-30s %-50s %s\n" "${domain}" "${conf}" "${enabled}"
done

