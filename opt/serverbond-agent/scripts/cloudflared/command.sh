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

usage() {
    cat <<'USAGE'
Kullanım: cloudflared/command.sh <tunnel|service|update|version|login> [args]
USAGE
}

if ! command -v cloudflared >/dev/null 2>&1; then
    log_error "cloudflared komutu bulunamadı."
    exit 1
fi

SUBCOMMAND="${1:-}"
if [[ -z "${SUBCOMMAND}" ]]; then
    usage
    exit 1
fi
shift || true

case "${SUBCOMMAND}" in
    tunnel)
        log_info "cloudflared tunnel komutu çalıştırılıyor..."
        cloudflared tunnel "$@"
        ;;
    service)
        log_info "cloudflared service komutu çalıştırılıyor..."
        cloudflared service "$@"
        ;;
    update)
        log_info "cloudflared update komutu çalıştırılıyor..."
        cloudflared update "$@"
        ;;
    version)
        cloudflared --version
        ;;
    login)
        log_info "cloudflared login komutu çalıştırılıyor..."
        cloudflared login "$@"
        ;;
    *)
        log_error "Desteklenmeyen cloudflared komutu: ${SUBCOMMAND}"
        usage
        exit 1
        ;;
esac
