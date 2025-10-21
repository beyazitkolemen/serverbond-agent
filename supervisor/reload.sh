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

log_info "Supervisor konfigürasyonu yeniden yükleniyor..."
if supervisorctl reread && supervisorctl update; then
    log_success "Supervisor konfigürasyonu güncellendi."
else
    log_error "Supervisor reload işlemi başarısız."
    exit 1
fi

