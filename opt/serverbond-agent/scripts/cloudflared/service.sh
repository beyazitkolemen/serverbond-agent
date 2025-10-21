#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_SH="${SCRIPTS_DIR}/lib.sh"

if [[ ! -f "${LIB_SH}" ]]; then
    echo "lib.sh bulunamadı: ${LIB_SH}" >&2
    exit 1
fi

# shellcheck source=../lib.sh
source "${LIB_SH}"

require_root

SERVICE_NAME="cloudflared"

usage() {
    cat <<'USAGE'
Kullanım: cloudflared/service.sh <start|stop|restart|reload|status|enable|disable|logs>
USAGE
}

ACTION="${1:-}"
if [[ -z "${ACTION}" ]]; then
    usage
    exit 1
fi

case "${ACTION}" in
    start|stop|restart|reload|enable|disable)
        if systemctl_safe "${ACTION}" "${SERVICE_NAME}"; then
            log_success "cloudflared servisi ${ACTION} işlemi tamamlandı"
        else
            log_error "cloudflared servisi ${ACTION} işlemi başarısız"
            exit 1
        fi
        ;;
    status)
        log_info "cloudflared servis durumu görüntüleniyor..."
        systemctl status "${SERVICE_NAME}" --no-pager
        ;;
    logs)
        log_info "cloudflared günlükleri gösteriliyor..."
        journalctl -u "${SERVICE_NAME}" --no-pager
        ;;
    *)
        log_error "Geçersiz eylem: ${ACTION}"
        usage
        exit 1
        ;;
esac
