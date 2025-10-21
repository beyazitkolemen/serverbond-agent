#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMMON_SH="${ROOT_DIR}/scripts/common.sh"
PHP_COMMON="${SCRIPT_DIR}/_common.sh"

if [[ ! -f "${COMMON_SH}" || ! -f "${PHP_COMMON}" ]]; then
    echo "Gerekli ortak scriptler bulunamadı." >&2
    exit 1
fi

# shellcheck source=../scripts/common.sh
source "${COMMON_SH}"
# shellcheck source=php/_common.sh
source "${PHP_COMMON}"

require_root

SERVICE_NAME="$(php_detect_fpm_service)"

log_info "PHP-FPM servisi (${SERVICE_NAME}) yeniden başlatılıyor..."
if systemctl_safe restart "${SERVICE_NAME}"; then
    log_success "PHP-FPM yeniden başlatıldı."
else
    log_error "PHP-FPM yeniden başlatılamadı."
    exit 1
fi

