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
SCRIPT_NAME="build"
INSTALL=true

usage() {
    cat <<'USAGE'
Kullanım: deploy/npm_build.sh [--path /var/www/current] [--script build] [--skip-install]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            TARGET_DIR="${2:-}"
            shift 2
            ;;
        --script)
            SCRIPT_NAME="${2:-build}"
            shift 2
            ;;
        --skip-install)
            INSTALL=false
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
    log_error "Geçerli deploy dizini bulunamadı."
    exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
    log_error "npm komutu bulunamadı."
    exit 1
fi

(
    cd "${TARGET_DIR}"
    if [[ "${INSTALL}" == true ]]; then
        log_info "npm install çalıştırılıyor..."
        npm install
    fi
    log_info "npm run ${SCRIPT_NAME} çalıştırılıyor..."
    npm run "${SCRIPT_NAME}"
)

log_success "NPM scripti tamamlandı."

