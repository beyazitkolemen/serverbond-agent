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

