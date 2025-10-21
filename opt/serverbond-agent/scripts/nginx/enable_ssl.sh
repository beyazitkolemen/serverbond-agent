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
EMAIL=""
STAGING=false

usage() {
    cat <<'USAGE'
Kullanım: nginx/enable_ssl.sh --domain example.com --email admin@example.com [--staging]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain)
            DOMAIN="${2:-}"
            shift 2
            ;;
        --email)
            EMAIL="${2:-}"
            shift 2
            ;;
        --staging)
            STAGING=true
            shift
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

if [[ -z "${DOMAIN}" || -z "${EMAIL}" ]]; then
    log_error "--domain ve --email zorunludur."
    exit 1
fi

if ! check_command certbot; then
    log_error "certbot bulunamadı. Önce ssl/install_certbot.sh çalıştırın."
    exit 1
fi

ARGS=(--nginx --non-interactive --agree-tos -d "${DOMAIN}" -m "${EMAIL}")
if [[ "${STAGING}" == true ]]; then
    ARGS+=(--staging)
fi

log_info "Let's Encrypt sertifikası alınıyor..."
certbot "${ARGS[@]}"

log_success "${DOMAIN} için SSL etkinleştirildi."
