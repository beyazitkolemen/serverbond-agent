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

if ! check_command certbot; then
    log_error "certbot bulunamadı."
    exit 1
fi

certbot certificates

