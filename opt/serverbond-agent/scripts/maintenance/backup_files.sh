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

SOURCE_DIR=""
OUTPUT_FILE=""
EXCLUDE="node_modules vendor storage/logs"

usage() {
    cat <<'USAGE'
Kullanım: maintenance/backup_files.sh --path /var/www/current [--output /backups/site.tar.gz]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            SOURCE_DIR="${2:-}"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="${2:-}"
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

if [[ -z "${SOURCE_DIR}" ]]; then
    log_error "--path zorunludur."
    exit 1
fi

if [[ ! -d "${SOURCE_DIR}" ]]; then
    log_error "Kaynak dizin bulunamadı: ${SOURCE_DIR}"
    exit 1
fi

if [[ -z "${OUTPUT_FILE}" ]]; then
    TIMESTAMP="$(date +%Y%m%d%H%M%S)"
    OUTPUT_FILE="${SOURCE_DIR%/}_${TIMESTAMP}.tar.gz"
fi

log_info "Dosyalar yedekleniyor -> ${OUTPUT_FILE}"
EXCLUDE_ARGS=()
for item in ${EXCLUDE}; do
    EXCLUDE_ARGS+=(--exclude "${item}")
done

tar czf "${OUTPUT_FILE}" "${EXCLUDE_ARGS[@]}" -C "${SOURCE_DIR}" .
log_success "Dosya yedeği oluşturuldu: ${OUTPUT_FILE}"
