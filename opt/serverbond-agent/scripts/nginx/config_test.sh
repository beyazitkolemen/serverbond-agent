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

log_info "Nginx konfigürasyonu test ediliyor..."
if nginx -t; then
    log_success "Konfigürasyon testi başarıyla tamamlandı."
else
    log_error "Konfigürasyon testi başarısız oldu."
    exit 1
fi
