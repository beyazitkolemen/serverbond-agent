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

require_root

SERVICE_NAME="${REDIS_SERVICE_NAME:-redis-server}"

log_info "Redis (${SERVICE_NAME}) servisi başlatılıyor..."
if systemctl_safe start "${SERVICE_NAME}"; then
    log_success "Redis servisi başlatıldı."
else
    log_error "Redis servisi başlatılamadı."
    exit 1
fi

