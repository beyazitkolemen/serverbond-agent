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

MODE="${1:-upgrade}"
export DEBIAN_FRONTEND=noninteractive

case "$MODE" in
    upgrade)
        log_info "Paket listeleri güncelleniyor..."
        apt-get update -qq
        log_info "Yüklü paketler yükseltiliyor..."
        apt-get upgrade -y -qq
        ;;
    dist-upgrade)
        log_info "Paket listeleri güncelleniyor..."
        apt-get update -qq
        log_info "Dağıtım yükseltmesi uygulanıyor..."
        apt-get dist-upgrade -y -qq
        ;;
    security)
        log_info "Sadece güvenlik güncellemeleri taranıyor..."
        apt-get update -qq
        if check_command unattended-upgrade; then
            unattended-upgrade -d
        else
            log_warning "unattended-upgrade bulunamadı, standart upgrade uygulanıyor."
            apt-get upgrade -y -qq
        fi
        ;;
    *)
        log_error "Bilinmeyen mod: ${MODE}"
        echo "Kullanım: system/update_os.sh [upgrade|dist-upgrade|security]" >&2
        exit 1
        ;;
esac

log_info "Gereksiz paketler temizleniyor..."
apt-get autoremove -y -qq
apt-get autoclean -y -qq

log_success "Sistem güncellemesi tamamlandı."
