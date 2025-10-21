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

SERVICE_NAME="$(mysql_detect_service)"
SERVICE_STATUS="stopped"
if check_service "${SERVICE_NAME}"; then
    SERVICE_STATUS="running"
fi

VERSION="$(mysql --version 2>/dev/null || echo 'mysql bulunamadı')"
UPTIME="$(mysqladmin -u"${MYSQL_ROOT_USER}" ${MYSQL_ROOT_PASSWORD:+-p"${MYSQL_ROOT_PASSWORD}"} status 2>/dev/null | awk -F': ' '/Uptime/ {print $2}')"
THREADS="$(mysqladmin -u"${MYSQL_ROOT_USER}" ${MYSQL_ROOT_PASSWORD:+-p"${MYSQL_ROOT_PASSWORD}"} status 2>/dev/null | awk -F'  ' '{for(i=1;i<=NF;i++){if($i ~ /^Threads=/){split($i,a,"=");print a[2]}}}')"

cat <<EOF
MySQL Servis: ${SERVICE_NAME} (${SERVICE_STATUS})
Sürüm: ${VERSION}
Uptime: ${UPTIME:-bilinmiyor}
Aktif Thread: ${THREADS:-?}
EOF
