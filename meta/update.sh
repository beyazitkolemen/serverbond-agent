#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -d "${ROOT_DIR}/.git" ]]; then
    echo "Git deposu bulunamadı: ${ROOT_DIR}" >&2
    exit 1
fi

cd "${ROOT_DIR}"
git pull --rebase

