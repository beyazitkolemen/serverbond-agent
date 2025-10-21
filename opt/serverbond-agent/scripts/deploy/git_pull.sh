#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)"
LIB_SH="${SCRIPTS_DIR}/lib.sh"
DEPLOY_COMMON="${SCRIPT_DIR}/_common.sh"

if [[ ! -f "${LIB_SH}" || ! -f "${DEPLOY_COMMON}" ]]; then
    echo "Gerekli ortak scriptler bulunamadı." >&2
    exit 1
fi

# shellcheck source=../lib.sh
source "${LIB_SH}"
# shellcheck source=deploy/_common.sh
source "${DEPLOY_COMMON}"

require_root

TARGET_DIR=""
RESET=false

usage() {
    cat <<'USAGE'
Kullanım: deploy/git_pull.sh [--path /var/www/current] [--reset]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            TARGET_DIR="${2:-}"
            shift 2
            ;;
        --reset)
            RESET=true
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

if [[ -z "${TARGET_DIR}" ]]; then
    TARGET_DIR="$(current_release_dir)"
fi

if [[ -z "${TARGET_DIR}" || ! -d "${TARGET_DIR}" ]]; then
    log_error "Geçerli bir deploy dizini bulunamadı."
    exit 1
fi

log_info "Git deposu güncelleniyor: ${TARGET_DIR}"
(
    cd "${TARGET_DIR}"
    if [[ "${RESET}" == true ]]; then
        git fetch --all
        git reset --hard origin/"$(git rev-parse --abbrev-ref HEAD)"
    else
        git pull --rebase --autostash
    fi
)
log_success "Git deposu güncellendi."

