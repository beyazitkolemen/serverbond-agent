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

REPO=""
BRANCH="main"
DEPTH=1
ACTIVATE=false

usage() {
    cat <<'USAGE'
Kullanım: deploy/clone_repo.sh --repo git@github.com:example/repo.git [--branch main] [--depth 1] [--activate]
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
        --activate)
            ACTIVATE=true
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
TARGET_DIR="$(release_from_timestamp "${TIMESTAMP}")"

log_info "Depo klonlanıyor -> ${TARGET_DIR}"
if ! command -v git >/dev/null 2>&1; then
    log_error "git komutu bulunamadı."
    exit 1
fi

git clone --branch "${BRANCH}" --depth "${DEPTH}" "${REPO}" "${TARGET_DIR}"
log_success "Depo klonlandı: ${TARGET_DIR}"

if [[ "${ACTIVATE}" == true ]]; then
    switch_release "${TARGET_DIR}"
fi

printf '%s\n' "${TARGET_DIR}"

