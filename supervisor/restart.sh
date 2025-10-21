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

require_root

SERVICE_NAME="${SUPERVISOR_SERVICE_NAME:-supervisor}"

log_info "Supervisor servisi (${SERVICE_NAME}) yeniden başlatılıyor..."
if systemctl_safe restart "${SERVICE_NAME}"; then
    log_success "Supervisor yeniden başlatıldı."
else
    log_error "Supervisor yeniden başlatılamadı."
    exit 1
fi

