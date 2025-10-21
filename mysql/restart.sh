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

log_info "MySQL servisi (${SERVICE_NAME}) yeniden başlatılıyor..."
if systemctl_safe restart "${SERVICE_NAME}"; then
    log_success "MySQL servisi yeniden başlatıldı."
else
    log_error "MySQL servisi yeniden başlatılamadı."
    exit 1
fi

