#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMMON_SH="${ROOT_DIR}/scripts/common.sh"

if [[ ! -f "${COMMON_SH}" ]]; then
    echo "common.sh bulunamadı: ${COMMON_SH}" >&2
    exit 1
fi

# shellcheck source=../scripts/common.sh
source "${COMMON_SH}"

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

