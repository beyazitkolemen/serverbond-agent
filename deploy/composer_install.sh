#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMMON_SH="${ROOT_DIR}/scripts/common.sh"
DEPLOY_COMMON="${SCRIPT_DIR}/_common.sh"

if [[ ! -f "${COMMON_SH}" || ! -f "${DEPLOY_COMMON}" ]]; then
    echo "Gerekli ortak scriptler bulunamadı." >&2
    exit 1
fi

# shellcheck source=../scripts/common.sh
source "${COMMON_SH}"
# shellcheck source=deploy/_common.sh
source "${DEPLOY_COMMON}"

require_root

TARGET_DIR=""
NO_DEV=false
OPTIMIZE=false

usage() {
    cat <<'USAGE'
Kullanım: deploy/composer_install.sh [--path /var/www/current] [--no-dev] [--optimize]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            TARGET_DIR="${2:-}"
            shift 2
            ;;
        --no-dev)
            NO_DEV=true
            shift
            ;;
        --optimize)
            OPTIMIZE=true
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

if ! command -v composer >/dev/null 2>&1; then
    log_error "composer komutu bulunamadı."
    exit 1
fi

ARGS=(install --no-interaction --prefer-dist)
[[ "${NO_DEV}" == true ]] && ARGS+=(--no-dev)
[[ "${OPTIMIZE}" == true ]] && ARGS+=(--optimize-autoloader)

log_info "Composer bağımlılıkları yükleniyor..."
(
    cd "${TARGET_DIR}"
    composer "${ARGS[@]}"
)
log_success "Composer kurulumu tamamlandı."

