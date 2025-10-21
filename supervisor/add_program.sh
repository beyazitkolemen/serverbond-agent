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
COMMAND=""
USER="www-data"
DIRECTORY=""
AUTOSTART=true
AUTORESTART=true
LOG_DIR="/var/log/supervisor"

usage() {
    cat <<'USAGE'
Kullanım: supervisor/add_program.sh --name queue --command "php artisan queue:work" [--user www-data] [--directory /var/www/current]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)
            NAME="${2:-}"
            shift 2
            ;;
        --command)
            COMMAND="${2:-}"
            shift 2
            ;;
        --user)
            USER="${2:-}"
            shift 2
            ;;
        --directory)
            DIRECTORY="${2:-}"
            shift 2
            ;;
        --no-autostart)
            AUTOSTART=false
            shift
            ;;
        --no-autorestart)
            AUTORESTART=false
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

if [[ -z "${NAME}" || -z "${COMMAND}" ]]; then
    log_error "--name ve --command zorunludur."
    exit 1
fi

CONFIG_DIR="${SUPERVISOR_CONF_DIR:-/etc/supervisor/conf.d}"
CONFIG_FILE="${CONFIG_DIR}/${NAME}.conf"
mkdir -p "${CONFIG_DIR}" "${LOG_DIR}"

cat > "${CONFIG_FILE}" <<CFG
[program:${NAME}]
command=${COMMAND}
user=${USER}
autostart=${AUTOSTART}
autorestart=${AUTORESTART}
redirect_stderr=true
stdout_logfile=${LOG_DIR}/${NAME}.log
stderr_logfile=${LOG_DIR}/${NAME}.error.log
CFG

if [[ -n "${DIRECTORY}" ]]; then
    echo "directory=${DIRECTORY}" >> "${CONFIG_FILE}"
fi

log_info "Supervisor programı eklendi: ${CONFIG_FILE}"
"${SCRIPT_DIR}/reload.sh"

