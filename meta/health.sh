#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_STATUS="${SCRIPT_DIR}/../system/status.sh"

if [[ ! -x "${SYSTEM_STATUS}" ]]; then
    echo "system/status.sh bulunamadı." >&2
    exit 1
fi

"${SYSTEM_STATUS}"
