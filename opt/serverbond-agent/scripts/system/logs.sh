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

LINES=200
FOLLOW=false
SERVICE=""

usage() {
    cat <<'USAGE'
Kullanım: system/logs.sh [--lines <adet>] [--service <unit>] [--follow]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --lines)
            LINES="${2:-}"
            shift 2
            ;;
        --service)
            SERVICE="${2:-}"
            shift 2
            ;;
        --follow)
            FOLLOW=true
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

if command -v journalctl >/dev/null 2>&1; then
    CMD=(journalctl --no-pager -n "$LINES")
    if [[ "$FOLLOW" == true ]]; then
        CMD+=(--follow)
    fi
    if [[ -n "$SERVICE" ]]; then
        CMD+=(-u "$SERVICE")
    fi
    "${CMD[@]}"
else
    LOG_FILE="/var/log/syslog"
    [[ -f /var/log/messages ]] && LOG_FILE="/var/log/messages"
    log_warning "journalctl bulunamadı, ${LOG_FILE} dosyasından okunuyor."
    if [[ "$FOLLOW" == true ]]; then
        tail -n "$LINES" -f "$LOG_FILE"
    else
        tail -n "$LINES" "$LOG_FILE"
    fi
fi
