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

PROJECT_DIR="."
COMPOSE_FILE=""
DETACHED=true

usage() {
    cat <<'USAGE'
Kullanım: docker/compose_up.sh [--path /proje] [--file docker-compose.yml] [--no-detach]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            PROJECT_DIR="${2:-.}"
            shift 2
            ;;
        --file)
            COMPOSE_FILE="${2:-}"
            shift 2
            ;;
        --no-detach)
            DETACHED=false
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

if [[ ! -d "${PROJECT_DIR}" ]]; then
    log_error "Proje dizini bulunamadı: ${PROJECT_DIR}"
    exit 1
fi

COMPOSE_BIN=""
if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_BIN="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    COMPOSE_BIN="docker compose"
else
    log_error "docker-compose veya docker compose komutu bulunamadı."
    exit 1
fi

ARGS=(up)
[[ "${DETACHED}" == true ]] && ARGS+=(-d)
[[ -n "${COMPOSE_FILE}" ]] && ARGS+=(-f "${COMPOSE_FILE}")

log_info "Docker Compose yükseltiliyor..."
(
    cd "${PROJECT_DIR}"
    ${COMPOSE_BIN} "${ARGS[@]}"
)
log_success "Docker Compose hizmetleri başlatıldı."

