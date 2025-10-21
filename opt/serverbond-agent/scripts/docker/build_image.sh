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

PATH_DIR="."
TAG=""
NO_CACHE=false

usage() {
    cat <<'USAGE'
Kullanım: docker/build_image.sh --tag my-image:latest [--path .] [--no-cache]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            PATH_DIR="${2:-.}"
            shift 2
            ;;
        --tag)
            TAG="${2:-}"
            shift 2
            ;;
        --no-cache)
            NO_CACHE=true
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

if [[ -z "${TAG}" ]]; then
    log_error "--tag zorunludur."
    exit 1
fi

if ! check_command docker; then
    log_error "docker komutu bulunamadı."
    exit 1
fi

ARGS=(-t "${TAG}" "${PATH_DIR}")
[[ "${NO_CACHE}" == true ]] && ARGS=(--no-cache "${ARGS[@]}")

log_info "Docker imajı oluşturuluyor: ${TAG}"
docker build "${ARGS[@]}"
log_success "Docker imajı oluşturuldu: ${TAG}"

