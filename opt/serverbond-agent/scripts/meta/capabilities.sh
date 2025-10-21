#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find "${ROOT_DIR}" -maxdepth 2 -type f -name '*.sh' \
    | sed "s#${ROOT_DIR}/##" \
    | sort

