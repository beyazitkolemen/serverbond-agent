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

CURRENT="$(current_release_dir)"
if [[ -z "${CURRENT}" ]]; then
    log_error "Aktif sürüm bağlantısı bulunamadı."
    exit 1
fi

if [[ ! -d "${DEPLOY_RELEASES_DIR}" ]]; then
    log_error "Releases klasörü bulunamadı: ${DEPLOY_RELEASES_DIR}"
    exit 1
fi

mapfile -t RELEASES < <(ls -1 "${DEPLOY_RELEASES_DIR}" | sort)
TARGET=""
for ((idx=${#RELEASES[@]}-1; idx>=0; idx--)); do
    CANDIDATE="${DEPLOY_RELEASES_DIR}/${RELEASES[$idx]}"
    if [[ "${CANDIDATE}" == "${CURRENT}" ]]; then
        continue
    fi
    TARGET="${CANDIDATE}"
    break
fi

if [[ -z "${TARGET}" ]]; then
    log_error "Geri dönülecek eski sürüm bulunamadı."
    exit 1
fi

log_info "Rollback uygulanıyor: ${TARGET}"
switch_release "${TARGET}"
log_success "Rollback tamamlandı."

