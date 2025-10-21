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

CURRENT="$(current_release_dir)"

if [[ ! -d "${DEPLOY_RELEASES_DIR}" ]]; then
    log_warning "Releases klasörü bulunamadı: ${DEPLOY_RELEASES_DIR}"
    exit 0
fi

printf "%-20s %s\n" "ZAMAN" "YOL"
printf '%*s\n' 80 '' | tr ' ' '-'
for release in $(ls -1 "${DEPLOY_RELEASES_DIR}" | sort); do
    PATH_FULL="${DEPLOY_RELEASES_DIR}/${release}"
    MARK=" "
    if [[ "${PATH_FULL}" == "${CURRENT}" ]]; then
        MARK="*"
    fi
    printf "%s %-20s %s\n" "${MARK}" "${release}" "${PATH_FULL}"
done

