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

log_info "Nginx servisi yeniden başlatılıyor..."
if systemctl_safe restart nginx; then
    log_success "Nginx servisi yeniden başlatıldı."
else
    log_error "Nginx servisi yeniden başlatılamadı."
    exit 1
fi
