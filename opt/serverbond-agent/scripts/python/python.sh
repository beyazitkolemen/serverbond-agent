#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_SH="${SCRIPTS_DIR}/lib.sh"

if [[ ! -f "${LIB_SH}" ]]; then
    echo "lib.sh bulunamadı: ${LIB_SH}" >&2
    exit 1
fi

# shellcheck source=../lib.sh
source "${LIB_SH}"

require_root

RUN_AS="www-data"
PYTHON_BIN="python3"

usage() {
    cat <<'USAGE'
Kullanım: python/python.sh [--user www-data] [--python python3.12] [--] <komut>
  --user USER      Komutu belirtilen kullanıcı ile çalıştır (varsayılan: www-data)
  --python BINARY  Kullanılacak python betiği (varsayılan: python3)
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)
            RUN_AS="${2:-}"
            if [[ -z "${RUN_AS}" ]]; then
                log_error "--user için bir kullanıcı belirtilmelidir"
                exit 1
            fi
            shift 2
            ;;
        --python)
            PYTHON_BIN="${2:-}"
            if [[ -z "${PYTHON_BIN}" ]]; then
                log_error "--python için bir betik belirtilmelidir"
                exit 1
            fi
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
    log_error "${PYTHON_BIN} komutu bulunamadı."
    exit 1
fi

log_info "${PYTHON_BIN} komutu çalıştırılıyor (kullanıcı: ${RUN_AS})..."

if [[ "$RUN_AS" == "root" || "$RUN_AS" == "0" ]]; then
    "${PYTHON_BIN}" "$@"
else
    run_as_user "$RUN_AS" "${PYTHON_BIN}" "$@"
fi
