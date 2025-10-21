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
VOLUMES=false

usage() {
    cat <<'USAGE'
Kullanım: docker/remove_container.sh --name container [--volumes]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)
            NAME="${2:-}"
            shift 2
            ;;
        --volumes)
            VOLUMES=true
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

if [[ -z "${NAME}" ]]; then
    log_error "--name zorunludur."
    exit 1
fi

if ! check_command docker; then
    log_error "docker komutu bulunamadı."
    exit 1
fi

ARGS=(rm)
[[ "${VOLUMES}" == true ]] && ARGS+=(-v)
ARGS+=("${NAME}")

log_info "Docker container siliniyor: ${NAME}"
docker "${ARGS[@]}"
log_success "${NAME} container silindi."

