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

DOMAIN=""

usage() {
    cat <<'USAGE'
Kullanım: ssl/remove_ssl.sh --domain example.com
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain)
            DOMAIN="${2:-}"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "Bilinmeyen seçenek: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "${DOMAIN}" ]]; then
    log_error "--domain zorunludur."
    exit 1
fi

if ! check_command certbot; then
    log_error "certbot bulunamadı."
    exit 1
fi

log_info "${DOMAIN} için SSL sertifikası siliniyor..."
certbot delete --cert-name "${DOMAIN}" --non-interactive --quiet || log_warning "Sertifika bulunamadı veya silinemedi."

if check_command systemctl; then
    systemctl_safe reload nginx || true
fi

log_success "${DOMAIN} için SSL kaldırıldı."

