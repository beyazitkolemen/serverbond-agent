#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)"
LIB_SH="${SCRIPTS_DIR}/lib.sh"
PHP_COMMON="${SCRIPT_DIR}/_common.sh"

if [[ ! -f "${LIB_SH}" || ! -f "${PHP_COMMON}" ]]; then
    echo "Gerekli ortak scriptler bulunamadı." >&2
    exit 1
fi

# shellcheck source=../lib.sh
source "${LIB_SH}"
# shellcheck source=php/_common.sh
source "${PHP_COMMON}"

PHP_BIN_PATH="$(php_bin)"

VERSION_OUTPUT="$("${PHP_BIN_PATH}" -v 2>/dev/null || echo 'PHP bulunamadı')"
MODULES_OUTPUT="$("${PHP_BIN_PATH}" -m 2>/dev/null || echo '')"
SERVICE_NAME="$(php_detect_fpm_service)"
SERVICE_STATUS="unknown"
if check_service "${SERVICE_NAME}"; then
    SERVICE_STATUS="running"
else
    SERVICE_STATUS="stopped"
fi

cat <<EOF
PHP Bilgisi:
${VERSION_OUTPUT}

PHP-FPM Servisi: ${SERVICE_NAME} (${SERVICE_STATUS})

Yüklü Modüller:
${MODULES_OUTPUT}
EOF
