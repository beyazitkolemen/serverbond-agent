#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${SCRIPTS_DIR}/.." && pwd)"
LIB_SH="${SCRIPTS_DIR}/lib.sh"
DEPLOY_COMMON="${SCRIPT_DIR}/_common.sh"
PHP_COMMON="${SCRIPTS_DIR}/php/_common.sh"

if [[ ! -f "${LIB_SH}" || ! -f "${DEPLOY_COMMON}" || ! -f "${PHP_COMMON}" ]]; then
    echo "Gerekli ortak scriptler bulunamadı." >&2
    exit 1
fi

# shellcheck source=../lib.sh
source "${LIB_SH}"
# shellcheck source=deploy/_common.sh
source "${DEPLOY_COMMON}"
# shellcheck source=php/_common.sh
source "${PHP_COMMON}"

require_root

REPO=""
BRANCH="main"
DEPTH=1
KEEP_RELEASES=5
RUN_COMPOSER=true
RUN_NPM=true
RUN_MIGRATE=true
RUN_CACHE_CLEAR=true

usage() {
    cat <<'USAGE'
Kullanım: deploy/deploy_project.sh --repo URL [--branch main] [--depth 1] [--keep 5] [--skip-composer] [--skip-npm] [--skip-migrate] [--skip-cache]
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)
            REPO="${2:-}"
            shift 2
            ;;
        --branch)
            BRANCH="${2:-}"
            shift 2
            ;;
        --depth)
            DEPTH="${2:-1}"
            shift 2
            ;;
        --keep)
            KEEP_RELEASES="${2:-5}"
            shift 2
            ;;
        --skip-composer)
            RUN_COMPOSER=false
            shift
            ;;
        --skip-npm)
            RUN_NPM=false
            shift
            ;;
        --skip-migrate)
            RUN_MIGRATE=false
            shift
            ;;
        --skip-cache)
            RUN_CACHE_CLEAR=false
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

if [[ -z "${REPO}" ]]; then
    log_error "--repo zorunludur."
    exit 1
fi

ensure_deploy_dirs
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
RELEASE_DIR="$(release_from_timestamp "${TIMESTAMP}")"

log_info "Yeni sürüm hazırlanıyor: ${RELEASE_DIR}"
if ! command -v git >/dev/null 2>&1; then
    log_error "git komutu bulunamadı."
    exit 1
fi

git clone --branch "${BRANCH}" --depth "${DEPTH}" "${REPO}" "${RELEASE_DIR}"
log_success "Kod deposu indirildi."

if [[ "${RUN_COMPOSER}" == true ]]; then
    "${SCRIPT_DIR}/composer_install.sh" --path "${RELEASE_DIR}" --no-dev --optimize
fi

if [[ "${RUN_NPM}" == true ]]; then
    "${SCRIPT_DIR}/npm_build.sh" --path "${RELEASE_DIR}" --script build
fi

if [[ "${RUN_MIGRATE}" == true ]]; then
    "${SCRIPT_DIR}/artisan_migrate.sh" --path "${RELEASE_DIR}" --force
fi

if [[ "${RUN_CACHE_CLEAR}" == true ]]; then
    "${SCRIPT_DIR}/cache_clear.sh" --path "${RELEASE_DIR}"
fi

log_info "Yeni sürüm aktif hale getiriliyor..."
switch_release "${RELEASE_DIR}"

if [[ -d "${DEPLOY_RELEASES_DIR}" ]]; then
    mapfile -t RELEASE_LIST < <(ls -1 "${DEPLOY_RELEASES_DIR}" | sort)
    COUNT="${#RELEASE_LIST[@]}"
    if [[ "${KEEP_RELEASES}" -gt 0 && "${COUNT}" -gt "${KEEP_RELEASES}" ]]; then
        TO_REMOVE=$((COUNT - KEEP_RELEASES))
        for ((i=0; i<TO_REMOVE; i++)); do
            OLD_DIR="${DEPLOY_RELEASES_DIR}/${RELEASE_LIST[$i]}"
            log_info "Eski sürüm temizleniyor: ${OLD_DIR}"
            rm -rf "${OLD_DIR}"
        done
    fi
fi

log_success "Dağıtım tamamlandı: ${RELEASE_DIR}"

