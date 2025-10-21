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

NAME=""

usage() {
    cat <<'USAGE'
Kullanım: supervisor/remove_program.sh --name queue
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)
            NAME="${2:-}"
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

if [[ -z "${NAME}" ]]; then
    log_error "--name zorunludur."
    exit 1
fi

CONFIG_DIR="${SUPERVISOR_CONF_DIR:-/etc/supervisor/conf.d}"
CONFIG_FILE="${CONFIG_DIR}/${NAME}.conf"

if [[ -f "${CONFIG_FILE}" ]]; then
    rm -f "${CONFIG_FILE}"
    log_info "${CONFIG_FILE} silindi."
else
    log_warning "${CONFIG_FILE} bulunamadı."
fi

if check_command supervisorctl; then
    supervisorctl stop "${NAME}" || true
fi

"${SCRIPT_DIR}/reload.sh"
log_success "Supervisor programı kaldırıldı: ${NAME}"

