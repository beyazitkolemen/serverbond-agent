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

usage() {
    cat <<'USAGE'
Kullanım: system/reboot.sh [--force]

--force    : systemctl yerine shutdown -r now kullanır.
USAGE
}

if [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

log_warning "Sunucu yeniden başlatılacak. Açık bağlantılar kesilecektir."

if [[ "${1:-}" == "--force" ]]; then
    log_info "shutdown -r now komutu çalıştırılıyor..."
    shutdown -r now
else
    log_info "systemctl reboot komutu çalıştırılıyor..."
    systemctl reboot
fi
