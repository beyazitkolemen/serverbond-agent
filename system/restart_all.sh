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

SERVICES=("nginx" "mysql" "redis-server")

if [[ -n "${PHP_FPM_SERVICE:-}" ]]; then
    SERVICES+=("${PHP_FPM_SERVICE}")
else
    PHP_FPM_CANDIDATE="$(find_systemd_unit 'php*-fpm.service' || true)"
    if [[ -n "${PHP_FPM_CANDIDATE}" ]]; then
        SERVICES+=("${PHP_FPM_CANDIDATE}")
    fi
fi

restart_service() {
    local service="$1"
    if systemctl list-unit-files "${service}" >/dev/null 2>&1 || \
       systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then
        log_info "${service} servisi yeniden başlatılıyor..."
        if systemctl_safe restart "${service}"; then
            log_success "${service} yeniden başlatıldı."
        else
            log_warning "${service} servisi yeniden başlatılamadı."
        fi
    else
        log_warning "${service} servisi bulunamadı, atlanıyor."
    fi
}

for service in "${SERVICES[@]}"; do
    restart_service "${service}"
done

log_success "Tüm temel servisler yeniden başlatıldı."
