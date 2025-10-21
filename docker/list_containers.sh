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

ALL=false

usage() {
    cat <<'USAGE'
Kullanım: docker/list_containers.sh [--all]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            ALL=true
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

if ! check_command docker; then
    log_error "docker komutu bulunamadı."
    exit 1
fi

if [[ "${ALL}" == true ]]; then
    docker ps -a
else
    docker ps
fi

