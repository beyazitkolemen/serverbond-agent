#!/usr/bin/env bash
set -euo pipefail

DEPLOY_BASE_DIR="${DEPLOY_BASE_DIR:-/var/www}";
DEPLOY_RELEASES_DIR="${DEPLOY_RELEASES_DIR:-${DEPLOY_BASE_DIR}/releases}";
DEPLOY_SHARED_DIR="${DEPLOY_SHARED_DIR:-${DEPLOY_BASE_DIR}/shared}";
DEPLOY_CURRENT_LINK="${DEPLOY_CURRENT_LINK:-${DEPLOY_BASE_DIR}/current}";

ensure_deploy_dirs() {
    mkdir -p "${DEPLOY_RELEASES_DIR}" "${DEPLOY_SHARED_DIR}"
}

current_release_dir() {
    if [[ -L "${DEPLOY_CURRENT_LINK}" ]]; then
        readlink -f "${DEPLOY_CURRENT_LINK}"
    fi
}

release_from_timestamp() {
    local ts="$1"
    echo "${DEPLOY_RELEASES_DIR}/${ts}"
}

switch_release() {
    local target="$1"
    if [[ ! -d "${target}" ]]; then
        log_error "Hedef sürüm bulunamadı: ${target}"
        return 1
    fi
    ln -sfn "${target}" "${DEPLOY_CURRENT_LINK}"
    log_success "${DEPLOY_CURRENT_LINK} -> ${target}"
}

