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

SERVICE_NAME="${REDIS_SERVICE_NAME:-redis-server}"

log_info "Redis (${SERVICE_NAME}) servisi durduruluyor..."
if systemctl_safe stop "${SERVICE_NAME}"; then
    log_success "Redis servisi durduruldu."
else
    log_error "Redis servisi durdurulamadı."
    exit 1
fi

